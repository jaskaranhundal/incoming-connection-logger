# Incoming Connection Logger

## Overview
The Incoming Connection Logger is a Bash script designed to monitor and log incoming network connections on a Linux system. This tool provides network administrators and users with insights into active connections, enhancing security and facilitating troubleshooting.

## Key Features
- **Real-time Monitoring**: Performs scans for new incoming connections every 10 seconds, ensuring up-to-date information on network activity.
- **Detailed Logging**: Logs critical connection details, including:
  - **Source IP**: The IP address from which the connection originates.
  - **Destination IP**: The IP address of the system receiving the connection.
  - **Source Port**: The port number on the source machine.
  - **Destination Port**: The port number on the destination machine.
  - **Process Information**: The name and PID (Process ID) of the process associated with the connection.
- **CSV Output**: Stores all logged connections in a CSV file (`incoming_connection_log.csv`), allowing for easy analysis and data manipulation.
- **Duplicate Connection Check**: Prevents logging of previously recorded connections to ensure unique entries.

## How to Use
1. **Clone the Repository**: 
   ```bash
   git clone https://gitlab.com/jaskaranhundal/incoming-connection-logger.git
