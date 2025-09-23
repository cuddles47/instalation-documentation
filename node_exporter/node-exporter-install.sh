#!/bin/bash


# Node Exporter Installation Script v1.9.1

# Author: Based on kewwi's documentation

# Description: Automated installation of Node Exporter on Ubuntu systems


set -e


# Configuration

NODE_EXPORTER_VERSION="1.9.1"

NODE_EXPORTER_USER="node_exporter"

NODE_EXPORTER_BINARY="/usr/local/bin/node_exporter"

NODE_EXPORTER_SERVICE="/etc/systemd/system/node_exporter.service"


# Colors for output

RED='\033[0;31m'

GREEN='\033[0;32m'

YELLOW='\033[1;33m'

NC='\033[0m' # No Color


# Logging function

log() {

    echo -e "${GREEN}[INFO]${NC} $1"

}


warn() {

    echo -e "${YELLOW}[WARN]${NC} $1"

}


error() {

    echo -e "${RED}[ERROR]${NC} $1"

    exit 1

}


# Check if user has sudo privileges

check_sudo() {

    if [[ $EUID -eq 0 ]]; then

        warn "Running as root user. This is acceptable but not recommended."

        return 0

    fi

    

    if ! sudo -n true 2>/dev/null; then

        log "Please enter your sudo password when prompted"

        if ! sudo -v; then

            error "This script requires sudo privileges"

        fi

    fi

}


# Step 1: Create system user for Node Exporter

create_user() {

    log "Step 1: Creating system user for Node Exporter..."

    

    if id "$NODE_EXPORTER_USER" &>/dev/null; then

        warn "User $NODE_EXPORTER_USER already exists, skipping creation"

    else

        sudo useradd --system --no-create-home --shell /bin/false $NODE_EXPORTER_USER

        log "User $NODE_EXPORTER_USER created successfully"

    fi

}


# Step 2: Download Node Exporter

download_node_exporter() {

    log "Step 2: Downloading Node Exporter v${NODE_EXPORTER_VERSION}..."

    

    DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

    

    if [[ -f "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" ]]; then

        warn "Archive already exists, skipping download"

    else

        wget $DOWNLOAD_URL || error "Failed to download Node Exporter"

        log "Node Exporter downloaded successfully"

    fi

}


# Step 3: Extract Node Exporter

extract_node_exporter() {

    log "Step 3: Extracting Node Exporter..."

    

    tar -xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz || error "Failed to extract archive"

    log "Node Exporter extracted successfully"

}


# Step 4: Move binary to /usr/local/bin

install_binary() {

    log "Step 4: Installing Node Exporter binary..."

    

    sudo mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter $NODE_EXPORTER_BINARY || error "Failed to move binary"

    sudo chown root:root $NODE_EXPORTER_BINARY

    sudo chmod 755 $NODE_EXPORTER_BINARY

    log "Node Exporter binary installed successfully"

}


# Step 5: Clean up

cleanup() {

    log "Step 5: Cleaning up temporary files..."

    

    rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*

    log "Cleanup completed"

}


# Step 6: Verify installation

verify_installation() {

    log "Step 6: Verifying Node Exporter installation..."

    

    if $NODE_EXPORTER_BINARY --version; then

        log "Node Exporter installation verified successfully"

    else

        error "Node Exporter verification failed"

    fi

}


# Step 8-9: Create systemd service file

create_service() {

    log "Steps 8-9: Creating systemd service file..."

    

    sudo tee $NODE_EXPORTER_SERVICE > /dev/null <<EOF

[Unit]

Description=Node Exporter

Wants=network-online.target

After=network-online.target

StartLimitIntervalSec=500

StartLimitBurst=5


[Service]

User=node_exporter

Group=node_exporter

Type=simple

Restart=on-failure

RestartSec=5s

ExecStart=/usr/local/bin/node_exporter \\

    --collector.logind


[Install]

WantedBy=multi-user.target

EOF

    

    log "Systemd service file created successfully"

}


# Step 10: Enable service

enable_service() {

    log "Step 10: Enabling Node Exporter service..."

    

    sudo systemctl daemon-reload

    sudo systemctl enable node_exporter

    log "Node Exporter service enabled successfully"

}


# Step 11: Start service

start_service() {

    log "Step 11: Starting Node Exporter service..."

    

    sudo systemctl start node_exporter

    log "Node Exporter service started successfully"

}


# Step 12: Check service status

check_status() {

    log "Step 12: Checking Node Exporter service status..."

    

    if sudo systemctl is-active --quiet node_exporter; then

        log "Node Exporter is running successfully!"

        echo

        sudo systemctl status node_exporter --no-pager

        echo

        log "Node Exporter metrics available at: http://localhost:9100/metrics"

    else

        error "Node Exporter service failed to start. Check logs with: sudo journalctl -u node_exporter"

    fi

}


# Main installation function

main() {

    log "Starting Node Exporter installation..."

    echo "======================================"

    

    check_sudo

    

    create_user

    download_node_exporter

    extract_node_exporter

    install_binary

    cleanup

    verify_installation

    create_service

    enable_service

    start_service

    check_status

    

    echo "======================================"

    log "Node Exporter installation completed successfully!"

    log "You can now configure Prometheus to scrape metrics from this node at port 9100"

}


# Help function

show_help() {

    cat << EOF

Node Exporter Installation Script v${NODE_EXPORTER_VERSION}


Usage: $0 [OPTIONS]


OPTIONS:

    -h, --help      Show this help message

    -v, --version   Show version information

    --uninstall     Uninstall Node Exporter


Examples:

    $0                  # Install Node Exporter

    $0 --help          # Show help

    $0 --uninstall     # Uninstall Node Exporter


Requirements:

    - Ubuntu 20.04+ (or compatible Linux distribution)

    - sudo privileges

    - wget command available

    - systemd service manager


EOF

}


# Uninstall function

uninstall_node_exporter() {

    log "Uninstalling Node Exporter..."

    

    # Stop and disable service

    sudo systemctl stop node_exporter 2>/dev/null || true

    sudo systemctl disable node_exporter 2>/dev/null || true

    

    # Remove service file

    sudo rm -f $NODE_EXPORTER_SERVICE

    

    # Remove binary

    sudo rm -f $NODE_EXPORTER_BINARY

    

    # Remove user

    sudo userdel $NODE_EXPORTER_USER 2>/dev/null || true

    

    # Reload systemd

    sudo systemctl daemon-reload

    

    log "Node Exporter uninstalled successfully"

}


# Parse command line arguments

case "${1:-}" in

    -h|--help)

        show_help

        exit 0

        ;;

    -v|--version)

        echo "Node Exporter Installation Script v${NODE_EXPORTER_VERSION}"

        exit 0

        ;;

    --uninstall)

        uninstall_node_exporter

        exit 0

        ;;

    "")

        main

        ;;

    *)

        error "Unknown option: $1. Use --help for usage information."

        ;;

esac
