#!/bin/bash

# File to store the output (CSV format)
output_file="incoming_connection_log.csv"

# Print headers for the CSV file if the file doesn't exist
if [[ ! -f $output_file ]]; then
    echo "S.No,Source IP,Destination IP,Source Port,Destination Port,Process (PID)" > $output_file
fi

# Declare associative arrays to store unique connections for current and previous scans
declare -A old_connections
declare -A new_connections

# Initialize serial number (based on the existing entries in the CSV file)
serial_number=$(($(tail -n +2 $output_file | wc -l) + 1))

# Perform the current scan and store connections in new_connections array
perform_scan() {
    new_connections=()

    echo "Performing scan for incoming connections..."
    ss_output=$(ss -ntu state established -p) # Capture the output
    echo -e "Raw ss output:\n$ss_output\n"  # Print raw output

    # Process the ss output with awk and read it directly into the loop
    while read -r src_ip dst_ip src_port dst_port process; do
        # Debugging: print what is being read
        echo "Read from awk: src_ip='$src_ip', dst_ip='$dst_ip', src_port='$src_port', dst_port='$dst_port', process='$process'"

        # Check if all variables are populated
        if [[ -n "$src_ip" && -n "$dst_ip" && -n "$src_port" && -n "$dst_port" ]]; then
            connection_key="$src_ip:$dst_ip:$src_port:$dst_port"
            new_connections[$connection_key]="$src_ip,$dst_ip,$src_port,$dst_port,$process"
            
            # Debugging: Print the connection key and the value being assigned
            echo "Adding to new_connections: $connection_key -> ${new_connections[$connection_key]}"
        else
            echo "Warning: One of the fields is empty. Skipping this connection."
        fi
    done < <(echo "$ss_output" | awk 'NR>1 {
        split($4, src, ":"); 
        split($5, dst, ":"); 
        print src[1], dst[1], src[2], dst[2], $6
    }')

    # Display the count and contents of new connections
    echo "Number of new connections after processing: ${#new_connections[@]}"
    for conn in "${!new_connections[@]}"; do
        echo "New connection: $conn -> ${new_connections[$conn]}"
    done
}

# Compare old and new connections, and add only new connections to the CSV file
compare_and_log_new_connections() {
    echo "Comparing connections..."
    for connection_key in "${!new_connections[@]}"; do
        echo "Checking connection: $connection_key"
        # If old_connections is empty (first run) or connection from new_connections is not found in old_connections, add it to the log
        if [[ -z "${old_connections[$connection_key]}" ]]; then
            csv_entry="${serial_number},${new_connections[$connection_key]}"

            # Log the connection details in CSV format
            echo "$csv_entry" >> $output_file

            # Increment the serial number
            ((serial_number++))
            echo "Logged new connection: $csv_entry"
        fi
    done
}

# Copy new_connections to old_connections for the next scan
update_old_connections() {
    # Clear the old_connections array
    old_connections=()

    # Copy each entry from new_connections to old_connections
    for connection_key in "${!new_connections[@]}"; do
        old_connections[$connection_key]="${new_connections[$connection_key]}"
    done
}

# Main function to run the monitoring process
monitor_incoming_connections() {
    while true; do
        perform_scan  # Perform the current scan

        # Compare new connections with the old ones and log only new connections
        compare_and_log_new_connections

        # After logging, update the old_connections array
        update_old_connections

        # Sleep for 10 seconds before checking again
        sleep 10
    done
}

# Run the function to monitor connections
monitor_incoming_connections
jaskarn_singh@lindera-mongod
