#!/usr/bin/env bash
#
# Logs newly-observed established inbound connections to a CSV for security triage.
# Each row is timestamped, so the log answers "when did this peer first appear".

set -euo pipefail

OUTPUT_FILE="${OUTPUT_FILE:-incoming_connection_log.csv}"
INTERVAL="${INTERVAL:-10}"
VERBOSE="${VERBOSE:-0}"

usage() {
    cat <<'EOF'
Usage: incoming_connection_log.sh [-o FILE] [-i SECONDS] [-v] [-1]

  -o FILE     CSV output path        (default: incoming_connection_log.csv)
  -i SECONDS  Poll interval          (default: 10)
  -v          Verbose progress to stderr
  -1          Single scan, then exit (for cron and tests)

Environment: OUTPUT_FILE, INTERVAL, VERBOSE override the defaults.
EOF
}

log() { [[ "$VERBOSE" == "1" ]] && printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2 || true; }

# Peers already written to the CSV, newline-delimited. Keyed peer_ip:peer_port:local_port
# so a peer that disconnects and reconnects on a new ephemeral port is logged as new.
# A flat string rather than declare -A: bash 3.2 has no associative arrays.
seen=$'\n'

# ss quotes nothing and its process column embeds commas
# (users:(("mongod",pid=1,fd=4))), which corrupts a naive CSV write.
csv_field() {
    local v=${1//\"/\"\"}
    printf '"%s"' "$v"
}

# Splitting host:port on the FIRST colon breaks every IPv6 address.
# The port is always after the LAST colon.
split_hostport() {
    SPLIT_HOST="${1%:*}"
    SPLIT_PORT="${1##*:}"
    SPLIT_HOST="${SPLIT_HOST#[}"
    SPLIT_HOST="${SPLIT_HOST%]}"
}

# Rebuild state from the CSV so -1/cron runs and restarts do not re-log known peers.
# Fields 1-5 are timestamps, IPs and ports: never contain a comma or quote.
seed_seen() {
    [[ -f "$OUTPUT_FILE" ]] || return 0
    local n=0 src_ip src_port dst_port
    while IFS=, read -r _ts src_ip src_port _dst_ip dst_port _rest; do
        src_ip=${src_ip//\"/}; src_port=${src_port//\"/}; dst_port=${dst_port//\"/}
        [[ "$src_ip" == "source_ip" || -z "$src_ip" ]] && continue
        seen="${seen}${src_ip}:${src_port}:${dst_port}"$'\n'
        n=$((n + 1))
    done < "$OUTPUT_FILE"
    log "seeded $n known connections from $OUTPUT_FILE"
}

scan() {
    local ss_output line local_ep peer_ep process key ts
    # ss column order: Netid Recv-Q Send-Q Local-Address:Port Peer-Address:Port [Process]
    ss_output=$(ss -Hntu state established -p 2>/dev/null || true)
    [[ -z "$ss_output" ]] && { log "no established connections"; return 0; }

    while read -r _netid _rq _sq local_ep peer_ep process; do
        [[ -z "${peer_ep:-}" ]] && continue

        # Local side is US (the destination of an inbound connection);
        # peer is the remote source. The original script had these reversed.
        split_hostport "$local_ep"; local dst_ip="$SPLIT_HOST" dst_port="$SPLIT_PORT"
        split_hostport "$peer_ep";  local src_ip="$SPLIT_HOST" src_port="$SPLIT_PORT"

        key="${src_ip}:${src_port}:${dst_port}"
        case "$seen" in *$'\n'"$key"$'\n'*) continue ;; esac
        seen="${seen}${key}"$'\n'

        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        printf '%s,%s,%s,%s,%s,%s\n' \
            "$(csv_field "$ts")" \
            "$(csv_field "$src_ip")" "$(csv_field "$src_port")" \
            "$(csv_field "$dst_ip")" "$(csv_field "$dst_port")" \
            "$(csv_field "${process:-}")" >> "$OUTPUT_FILE"
        log "new connection ${src_ip}:${src_port} -> ${dst_ip}:${dst_port}"
    done <<< "$ss_output"
}

main() {
    local once=0
    while getopts ":o:i:v1h" opt; do
        case "$opt" in
            o) OUTPUT_FILE="$OPTARG" ;;
            i) INTERVAL="$OPTARG" ;;
            v) VERBOSE=1 ;;
            1) once=1 ;;
            h) usage; exit 0 ;;
            *) usage >&2; exit 2 ;;
        esac
    done

    command -v ss >/dev/null || { echo "error: 'ss' not found (iproute2 required)" >&2; exit 1; }

    if [[ ! -f "$OUTPUT_FILE" ]]; then
        echo "timestamp_utc,source_ip,source_port,destination_ip,destination_port,process" > "$OUTPUT_FILE"
    fi

    seed_seen
    trap 'log "stopping"; exit 0' INT TERM

    if [[ "$once" == "1" ]]; then
        scan
        return 0
    fi

    while true; do
        scan
        sleep "$INTERVAL"
    done
}

main "$@"
