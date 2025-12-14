#!/bin/bash

# Installation script for WiFi Auto-Reconnect Daemon

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_NAME="com.ghostreconnect.wifi.plist"
PLIST_SOURCE="$SCRIPT_DIR/$PLIST_NAME"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"
DAEMON_NAME="com.ghostreconnect.wifi"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Check if daemon is loaded
is_loaded() {
    launchctl list | grep -q "$DAEMON_NAME"
}

# Install the daemon
install() {
    print_info "Installing WiFi Auto-Reconnect Daemon..."
    
    # Check if script exists
    if [ ! -f "$SCRIPT_DIR/wifi-reconnect.sh" ]; then
        print_error "wifi-reconnect.sh not found in $SCRIPT_DIR"
        exit 1
    fi
    
    # Create ~/bin directory if it doesn't exist
    mkdir -p "$HOME/bin"
    
    # Copy script to ~/bin to avoid macOS security restrictions
    SCRIPT_DEST="$HOME/bin/wifi-reconnect.sh"
    cp "$SCRIPT_DIR/wifi-reconnect.sh" "$SCRIPT_DEST"
    chmod +x "$SCRIPT_DEST"
    
    # Remove any extended attributes that might block execution
    xattr -c "$SCRIPT_DEST" 2>/dev/null
    
    print_success "Copied and made wifi-reconnect.sh executable in ~/bin"
    
    # Update plist with correct script path
    if [ ! -f "$PLIST_SOURCE" ]; then
        print_error "Plist file not found: $PLIST_SOURCE"
        exit 1
    fi
    
    # Create LaunchAgents directory if it doesn't exist
    mkdir -p "$HOME/Library/LaunchAgents"
    
    # Copy plist to LaunchAgents
    cp "$PLIST_SOURCE" "$PLIST_DEST"
    print_success "Copied plist to $PLIST_DEST"
    
    # Update the script path in the plist (second ProgramArguments entry)
    # Use ~/bin location to avoid macOS security restrictions
    print_info "Updating script path in plist..."
    sed -i '' "s|<string>.*wifi-reconnect.sh</string>|<string>$HOME/bin/wifi-reconnect.sh</string>|" "$PLIST_DEST"
    
    # Load the daemon
    if is_loaded; then
        print_info "Daemon is already loaded, unloading first..."
        launchctl unload "$PLIST_DEST" 2>/dev/null
    fi
    
    launchctl load "$PLIST_DEST"
    if [ $? -eq 0 ]; then
        print_success "Daemon loaded successfully"
        print_info "The daemon will start automatically on login"
        print_info "To start it now, run: launchctl start $DAEMON_NAME"
    else
        print_error "Failed to load daemon"
        exit 1
    fi
}

# Uninstall the daemon
uninstall() {
    print_info "Uninstalling WiFi Auto-Reconnect Daemon..."
    
    # Unload the daemon if it's running
    if is_loaded; then
        launchctl unload "$PLIST_DEST" 2>/dev/null
        print_success "Daemon unloaded"
    else
        print_info "Daemon is not loaded"
    fi
    
    # Remove plist file
    if [ -f "$PLIST_DEST" ]; then
        rm "$PLIST_DEST"
        print_success "Removed plist file"
    fi
    
    # Optionally remove the script from ~/bin (commented out to preserve the script)
    # if [ -f "$HOME/bin/wifi-reconnect.sh" ]; then
    #     rm "$HOME/bin/wifi-reconnect.sh"
    #     print_success "Removed script from ~/bin"
    # fi
    
    print_success "Uninstallation complete"
}

# Show status
status() {
    print_info "WiFi Auto-Reconnect Daemon Status"
    echo ""
    
    if is_loaded; then
        print_success "Daemon is loaded"
        echo ""
        echo "Daemon information:"
        launchctl list "$DAEMON_NAME" 2>/dev/null || echo "  Unable to get detailed status"
    else
        print_error "Daemon is not loaded"
    fi
    
    echo ""
    if [ -f "/tmp/wifi-reconnect.log" ]; then
        print_info "Recent log entries (last 10 lines):"
        echo ""
        tail -n 10 "/tmp/wifi-reconnect.log" 2>/dev/null || echo "  Log file is empty or not accessible"
    else
        print_info "No log file found (daemon may not have run yet)"
    fi
}

# Start the daemon
start() {
    if is_loaded; then
        launchctl start "$DAEMON_NAME"
        if [ $? -eq 0 ]; then
            print_success "Daemon started"
        else
            print_error "Failed to start daemon"
        fi
    else
        print_error "Daemon is not loaded. Run './install.sh install' first"
        exit 1
    fi
}

# Stop the daemon
stop() {
    if is_loaded; then
        launchctl stop "$DAEMON_NAME"
        if [ $? -eq 0 ]; then
            print_success "Daemon stopped"
        else
            print_error "Failed to stop daemon"
        fi
    else
        print_error "Daemon is not loaded"
        exit 1
    fi
}

# Show usage
usage() {
    echo "Usage: $0 {install|uninstall|status|start|stop}"
    echo ""
    echo "Commands:"
    echo "  install   - Install and load the daemon"
    echo "  uninstall - Unload and remove the daemon"
    echo "  status    - Show daemon status and recent logs"
    echo "  start     - Start the daemon (if installed)"
    echo "  stop      - Stop the daemon (if installed)"
    exit 1
}

# Main script logic
case "${1:-}" in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    status)
        status
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    *)
        usage
        ;;
esac
