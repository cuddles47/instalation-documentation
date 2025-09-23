
#!/bin/bash

# Prometheus Installation Script v3.5.0
# Description: Automated installation of Prometheus on Ubuntu systems

set -e

# Configuration
PROMETHEUS_VERSION="3.5.0"
PROMETHEUS_USER="prometheus"
PROMETHEUS_GROUP="prometheus"
PROMETHEUS_CONFIG_DIR="/etc/prometheus"
PROMETHEUS_DATA_DIR="/data"
PROMETHEUS_BIN_DIR="/usr/local/bin"
PROMETHEUS_SERVICE="/etc/systemd/system/prometheus.service"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

step() {
    echo -e "${BLUE}[STEP]${NC} $1"
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

# Step 1: Create system user for Prometheus
create_user() {
    step "Step 1: Creating system user for Prometheus..."
    
    if id "$PROMETHEUS_USER" &>/dev/null; then
        warn "User $PROMETHEUS_USER already exists, skipping creation"
    else
        sudo useradd --system --no-create-home --shell /bin/false $PROMETHEUS_USER
        log "User $PROMETHEUS_USER created successfully"
    fi
}

# Step 2: Download Prometheus
download_prometheus() {
    step "Step 2: Downloading Prometheus v${PROMETHEUS_VERSION}..."
    
    DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
    
    if [[ -f "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" ]]; then
        warn "Archive already exists, skipping download"
    else
        wget $DOWNLOAD_URL || error "Failed to download Prometheus"
        log "Prometheus downloaded successfully"
    fi
}

# Step 3: Extract and move Prometheus files
extract_and_setup() {
    step "Step 3: Extracting and setting up Prometheus files..."
    
    # Extract archive
    tar -xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz || error "Failed to extract archive"
    
    # Create directories
    sudo mkdir -p $PROMETHEUS_DATA_DIR $PROMETHEUS_CONFIG_DIR
    
    # Navigate to extracted directory
    cd prometheus-${PROMETHEUS_VERSION}.linux-amd64
    
    # Move binaries
    sudo mv prometheus promtool $PROMETHEUS_BIN_DIR/
    log "Binaries moved to $PROMETHEUS_BIN_DIR"
    
    # Move configuration file
    sudo mv prometheus.yml $PROMETHEUS_CONFIG_DIR/
    log "Configuration file moved to $PROMETHEUS_CONFIG_DIR"
    
    # Move console files if they exist
    if [[ -d "consoles" ]]; then
        sudo mv consoles $PROMETHEUS_CONFIG_DIR/
        log "Console templates moved to $PROMETHEUS_CONFIG_DIR"
    fi
    
    if [[ -d "console_libraries" ]]; then
        sudo mv console_libraries $PROMETHEUS_CONFIG_DIR/
        log "Console libraries moved to $PROMETHEUS_CONFIG_DIR"
    fi
    
    # Set ownership
    sudo chown -R $PROMETHEUS_USER:$PROMETHEUS_USER $PROMETHEUS_CONFIG_DIR $PROMETHEUS_DATA_DIR
    
    # Navigate back
    cd ..
    
    log "Prometheus files extracted and configured successfully"
}

# Step 4: Clean up
cleanup() {
    step "Step 4: Cleaning up temporary files..."
    
    rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64*
    log "Cleanup completed"
}

# Step 5: Verify installation
verify_installation() {
    step "Step 5: Verifying Prometheus installation..."
    
    if prometheus --version; then
        log "Prometheus installation verified successfully"
    else
        error "Prometheus verification failed"
    fi
}

# Step 6: Create systemd service file
create_service() {
    step "Step 6: Creating systemd service file..."
    
    sudo tee $PROMETHEUS_SERVICE > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/prometheus \\
    --config.file=/etc/prometheus/prometheus.yml \\
    --storage.tsdb.path=/data \\
    --web.console.templates=/etc/prometheus/consoles \\
    --web.console.libraries=/etc/prometheus/console_libraries \\
    --web.listen-address=0.0.0.0:9090 \\
    --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
EOF
    
    log "Systemd service file created successfully"
}

# Step 7: Start Prometheus
start_prometheus() {
    step "Step 7: Starting Prometheus..."
    
    # Reload systemd daemon
    sudo systemctl daemon-reload
    
    # Enable service
    sudo systemctl enable prometheus
    log "Prometheus service enabled for auto-start"
    
    # Start service
    sudo systemctl start prometheus
    log "Prometheus service started successfully"
    
    # Check status
    if sudo systemctl is-active --quiet prometheus; then
        log "Prometheus is running successfully!"
        echo
        sudo systemctl status prometheus --no-pager
        echo
        log "Prometheus web interface available at: http://localhost:9090"
        log "Prometheus metrics available at: http://localhost:9090/metrics"
    else
        error "Prometheus service failed to start. Check logs with: sudo journalctl -u prometheus -f"
    fi
}

# Display Prometheus configuration
show_config() {
    log "Current Prometheus configuration:"
    echo "================================="
    if [[ -f "$PROMETHEUS_CONFIG_DIR/prometheus.yml" ]]; then
        cat $PROMETHEUS_CONFIG_DIR/prometheus.yml
    else
        warn "Configuration file not found at $PROMETHEUS_CONFIG_DIR/prometheus.yml"
    fi
    echo "================================="
}

# Main installation function
main() {
    log "Starting Prometheus installation..."
    echo "====================================="
    
    check_sudo
    
    create_user
    download_prometheus
    extract_and_setup
    cleanup
    verify_installation
    create_service
    start_prometheus
    
    echo
    echo "====================================="
    log "Prometheus installation completed successfully!"
    echo
    log "Next steps:"
    echo "  1. Configure targets in $PROMETHEUS_CONFIG_DIR/prometheus.yml"
    echo "  2. Access web interface at http://your-server-ip:9090"
    echo "  3. Check service status: sudo systemctl status prometheus"
    echo "  4. View logs: sudo journalctl -u prometheus -f"
    echo
    
    show_config
}

# Help function
show_help() {
    cat << EOF
Prometheus Installation Script v${PROMETHEUS_VERSION}

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help         Show this help message
    -v, --version      Show version information
    --config           Show current configuration
    --status           Show service status
    --logs             Show service logs
    --restart          Restart Prometheus service
    --uninstall        Uninstall Prometheus

Examples:
    $0                 # Install Prometheus
    $0 --help         # Show help
    $0 --status       # Check service status
    $0 --uninstall    # Uninstall Prometheus

Requirements:
    - Ubuntu 20.04+ (or compatible Linux distribution)
    - sudo privileges
    - wget command available
    - systemd service manager
    - At least 2GB RAM and 10GB disk space

EOF
}

# Show service status
show_status() {
    log "Prometheus service status:"
    sudo systemctl status prometheus --no-pager
    echo
    log "Recent logs:"
    sudo journalctl -u prometheus --no-pager -n 20
}

# Show logs
show_logs() {
    log "Following Prometheus logs (Press Ctrl+C to exit):"
    sudo journalctl -u prometheus -f
}

# Restart service
restart_service() {
    log "Restarting Prometheus service..."
    sudo systemctl restart prometheus
    if sudo systemctl is-active --quiet prometheus; then
        log "Prometheus restarted successfully"
    else
        error "Failed to restart Prometheus"
    fi
}

# Uninstall function
uninstall_prometheus() {
    log "Uninstalling Prometheus..."
    
    # Stop and disable service
    sudo systemctl stop prometheus 2>/dev/null || true
    sudo systemctl disable prometheus 2>/dev/null || true
    
    # Remove service file
    sudo rm -f $PROMETHEUS_SERVICE
    
    # Remove binaries
    sudo rm -f $PROMETHEUS_BIN_DIR/prometheus
    sudo rm -f $PROMETHEUS_BIN_DIR/promtool
    
    # Remove configuration directory
    sudo rm -rf $PROMETHEUS_CONFIG_DIR
    
    # Remove data directory
    read -p "Do you want to remove data directory $PROMETHEUS_DATA_DIR? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo rm -rf $PROMETHEUS_DATA_DIR
        log "Data directory removed"
    else
        log "Data directory preserved"
    fi
    
    # Remove user
    sudo userdel $PROMETHEUS_USER 2>/dev/null || true
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    log "Prometheus uninstalled successfully"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--version)
        echo "Prometheus Installation Script v${PROMETHEUS_VERSION}"
        exit 0
        ;;
    --config)
        show_config
        exit 0
        ;;
    --status)
        show_status
        exit 0
        ;;
    --logs)
        show_logs
        exit 0
        ;;
    --restart)
        restart_service
        exit 0
        ;;
    --uninstall)
        uninstall_prometheus
        exit 0
        ;;
    "")
        main
        ;;
    *)
        error "Unknown option: $1. Use --help for usage information."
        ;;
esac
