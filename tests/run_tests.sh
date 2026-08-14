#!/usr/bin/env bash
# Drives the logger against a stubbed `ss` so parsing and dedup are testable off-Linux.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
cat > "$WORK/bin/ss" <<'STUB'
#!/usr/bin/env bash
cat <<'OUT'
tcp   0  0  10.0.0.9:27017        10.0.0.15:51234        users:(("mongod",pid=1234,fd=45))
tcp   0  0  [2001:db8::1]:443     [2001:db8::99]:60001   users:(("nginx",pid=99,fd=7))
tcp   0  0  192.168.1.5:22        203.0.113.7:41022
OUT
STUB
chmod +x "$WORK/bin/ss"
export PATH="$WORK/bin:$PATH"

CSV="$WORK/out.csv"
fail() { echo "FAIL: $*" >&2; exit 1; }

bash "$ROOT/incoming_connection_log.sh" -o "$CSV" -1

python3 - "$CSV" <<'PY' || fail "CSV structure"
import csv, sys
rows = list(csv.reader(open(sys.argv[1])))
assert all(len(r) == 6 for r in rows), f"expected 6 columns, got {[len(r) for r in rows]}"
assert rows[0][0] == "timestamp_utc", "missing timestamp column"
ipv6 = [r for r in rows if r[1] == "2001:db8::99"]
assert ipv6, "IPv6 peer not parsed (host:port split on wrong colon)"
assert ipv6[0][2] == "60001", f"IPv6 port wrong: {ipv6[0][2]}"
assert any('mongod' in r[5] for r in rows), "comma-bearing process field lost"
sshd = [r for r in rows if r[4] == "22"]
assert sshd and sshd[0][1] == "203.0.113.7", "source/destination reversed"
print("ok: columns, IPv6, process field, direction")
PY

before=$(wc -l < "$CSV")
bash "$ROOT/incoming_connection_log.sh" -o "$CSV" -1
bash "$ROOT/incoming_connection_log.sh" -o "$CSV" -1
[[ "$(wc -l < "$CSV")" -eq "$before" ]] || fail "re-logged known peers across restarts"
echo "ok: dedup survives process restart"

echo "PASS"
