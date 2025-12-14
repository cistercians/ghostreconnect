#!/bin/bash

# WiFi Auto-Reconnect Daemon
# Monitors WiFi connection and automatically reconnects when disconnected

# Configuration
CHECK_INTERVAL=${CHECK_INTERVAL:-1}  # Default: 10 seconds
LOG_FILE="/tmp/wifi-reconnect.log"
WIFI_INTERFACE="en0"  # Default WiFi interface (may need adjustment for different Mac models)
PING_HOST="8.8.8.8"   # Google DNS for connectivity check
PING_TIMEOUT=2        # Ping timeout in seconds
OPEN_LOG_TERMINAL=${OPEN_LOG_TERMINAL:-true}  # Open terminal with log feed on startup

# Flag to control the main loop
RUNNING=true

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Signal handler for graceful shutdown
cleanup() {
    log "Received shutdown signal, stopping daemon..."
    RUNNING=false
    exit 0
}

trap cleanup SIGTERM SIGINT

# Function to open Terminal with live log feed
open_log_terminal() {
    if [ "$OPEN_LOG_TERMINAL" = "true" ]; then
        # Use AppleScript to open Terminal with tail -f command
        osascript -e "tell application \"Terminal\"" \
                  -e "activate" \
                  -e "do script \"tail -f $LOG_FILE\"" \
                  -e "end tell" >/dev/null 2>&1
    fi
}

# Function to check if WiFi is powered on
is_wifi_on() {
    local power_state=$(networksetup -getairportpower "$WIFI_INTERFACE" 2>/dev/null | grep -i "on")
    [ -n "$power_state" ]
}

# Function to check if connected to a WiFi network
is_wifi_connected() {
    local network=$(networksetup -getairportnetwork "$WIFI_INTERFACE" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$network" ] && ! echo "$network" | grep -qi "not associated"; then
        return 0
    fi
    return 1
}

# Function to check internet connectivity
has_internet() {
    ping -c 1 -W "$PING_TIMEOUT" "$PING_HOST" >/dev/null 2>&1
}

# Function to turn WiFi on
turn_wifi_on() {
    networksetup -setairportpower "$WIFI_INTERFACE" on >/dev/null 2>&1
    return $?
}

# Function to toggle WiFi (off then on)
toggle_wifi() {
    log "Toggling WiFi to force reconnection..."
    networksetup -setairportpower "$WIFI_INTERFACE" off >/dev/null 2>&1
    sleep 2
    networksetup -setairportpower "$WIFI_INTERFACE" on >/dev/null 2>&1
    return $?
}

# Function to reconnect WiFi
reconnect_wifi() {
    log "Attempting to reconnect WiFi..."
    
    if ! is_wifi_on; then
        log "WiFi is off, turning it on..."
        if turn_wifi_on; then
            log "WiFi turned on successfully"
            sleep 3  # Wait for WiFi to initialize
            return 0
        else
            log "ERROR: Failed to turn WiFi on"
            return 1
        fi
    fi
    
    # WiFi is on, but not connected or no internet
    if ! is_wifi_connected; then
        log "WiFi is on but not connected to a network, toggling..."
        toggle_wifi
        sleep 5  # Wait for reconnection
    elif ! has_internet; then
        log "WiFi is connected but no internet connectivity, toggling..."
        toggle_wifi
        sleep 5  # Wait for reconnection
    fi
    
    return 0
}

# Main monitoring loop
main() {
    log "WiFi Auto-Reconnect Daemon started"
    log "Check interval: ${CHECK_INTERVAL} seconds"
    log "WiFi interface: $WIFI_INTERFACE"
    
    # Open terminal with log feed if enabled
    open_log_terminal
    
    while $RUNNING; do
        # Check WiFi status - only log when issues are detected
        if ! is_wifi_on; then
            log "WiFi is off, attempting to turn it on..."
            reconnect_wifi
        elif ! is_wifi_connected; then
            log "WiFi is on but not connected to a network"
            reconnect_wifi
        elif ! has_internet; then
            log "WiFi is connected but no internet connectivity detected"
            reconnect_wifi
        fi
        # Connection is healthy - no logging needed
        
        # Sleep until next check
        sleep "$CHECK_INTERVAL"
    done
}

# Run main function
main
