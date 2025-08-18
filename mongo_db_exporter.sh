#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -u, --uri URI              MongoDB URI (e.g. mongodb://127.0.0.1:27017)"
    echo "  -w, --web-address ADDRESS  Web listen address (e.g. localhost:9094)"
    echo "  --auth-user USER          Auth username (optional)"
    echo "  --auth-pass PASS          Auth password (optional)"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -u mongodb://127.0.0.1:27017 -w localhost:9094"
    echo "  $0 --uri mongodb://127.0.0.1:27017 --web-address localhost:9094 --auth-user admin --auth-pass password"
    exit 1
}

# Default values
mongodb_uri=""
web_listen_address=""
auth_user=""
auth_pass=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--uri)
            mongodb_uri="$2"
            shift 2
            ;;
        -w|--web-address)
            web_listen_address="$2"
            shift 2
            ;;
        --auth-user)
            auth_user="$2"
            shift 2
            ;;
        --auth-pass)
            auth_pass="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# If no parameters provided, use interactive mode
if [ -z "$mongodb_uri" ] && [ -z "$web_listen_address" ]; then
    echo "No parameters provided, entering interactive mode..."
    read -p "Enter MongoDB URI (e.g. mongodb://127.0.0.1:27017): " mongodb_uri
    read -p "Enter web address and port number where the metrics should be hosted (e.g. localhost:9094): " web_listen_address
    read -p "Enter auth username (optional): " auth_user
    read -p "Enter auth password (optional): " auth_pass
fi

# Validate required parameters
if [ -z "$mongodb_uri" ] || [ -z "$web_listen_address" ]; then
    echo "Error: MongoDB URI and web listen address are required!"
    usage
fi

echo "Configuration:"
echo "MongoDB URI: $mongodb_uri"
echo "Web listen address: $web_listen_address"
if [ -n "$auth_user" ]; then
    echo "Auth username: $auth_user"
fi
if [ -n "$auth_pass" ]; then
    echo "Auth password: $auth_pass"
fi

# Install wget if not already installed
sudo apt-get update
sudo apt-get install -y wget

# Create mongodb_exporter user with no shell and no home directory
echo "Creating mongodb_exporter user..."
sudo useradd -rs /bin/false mongodb_exporter

# Download MongoDB Exporter
echo "Downloading MongoDB Exporter..."
wget https://github.com/percona/mongodb_exporter/releases/download/v0.47.0/mongodb_exporter-0.47.0.linux-amd64.tar.gz

# Extract the tar file
echo "Extracting MongoDB Exporter..."
tar -xvf mongodb_exporter-0.47.0.linux-amd64.tar.gz

# Move to /usr/local/bin and set permissions
echo "Installing MongoDB Exporter..."
sudo mv mongodb_exporter*/mongodb_exporter /usr/local/bin
sudo chown root:root /usr/local/bin/mongodb_exporter
sudo chmod 755 /usr/local/bin/mongodb_exporter

# Clean up downloaded files
rm -rf mongodb_exporter-0.47.0.linux-amd64.tar.gz mongodb_exporter-*

# Creating a service for the MongoDB exporter
echo "Creating systemd service..."
if [ -n "$auth_user" ] && [ -n "$auth_pass" ]; then
    # Both auth user and password are provided
    sudo tee /etc/systemd/system/mongodb_exporter.service > /dev/null <<EOF
[Unit]
Description=MongoDB Exporter
After=network.target

[Service]
User=mongodb_exporter
Group=mongodb_exporter
ExecStart=/usr/local/bin/mongodb_exporter --mongodb.uri=$mongodb_uri --web.listen-address=$web_listen_address --auth.user=$auth_user --auth.pass=$auth_pass --collect-all
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mongodb_exporter

[Install]
WantedBy=multi-user.target
EOF
else
    # No auth user or password provided
    sudo tee /etc/systemd/system/mongodb_exporter.service > /dev/null <<EOF
[Unit]
Description=MongoDB Exporter
After=network.target

[Service]
User=mongodb_exporter
Group=mongodb_exporter
ExecStart=/usr/local/bin/mongodb_exporter --mongodb.uri=$mongodb_uri --web.listen-address=$web_listen_address --collect-all
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mongodb_exporter

[Install]
WantedBy=multi-user.target
EOF
fi

# Reload systemd to read the new service file
echo "Configuring systemd service..."
sudo systemctl daemon-reload

# Start and enable the service
echo "Starting MongoDB Exporter service..."
sudo systemctl start mongodb_exporter
sudo systemctl enable mongodb_exporter

# Check service status
echo "Service status:"
sudo systemctl status mongodb_exporter --no-pager

echo "MongoDB Exporter installation completed!"
echo "You can check the service with: sudo systemctl status mongodb_exporter"
echo "View logs with: sudo journalctl -u mongodb_exporter -f"
