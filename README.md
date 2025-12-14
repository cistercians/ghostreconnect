# WiFi Auto-Reconnect Daemon

A shell script-based daemon that continuously monitors your WiFi connection status and automatically reconnects when disconnected. Designed for macOS, this tool runs as a background service using launchd.

## Features

- **Continuous Monitoring**: Automatically checks WiFi connection status at regular intervals (default: 10 seconds)
- **Automatic Reconnection**: Detects disconnections and attempts to reconnect automatically
- **Multiple Detection Methods**: Checks WiFi power state, network association, and internet connectivity
- **Background Service**: Runs as a launchd daemon, starting automatically on login
- **Logging**: Comprehensive logging for debugging and monitoring (only logs when issues are detected)
- **Live Log Terminal**: Automatically opens a Terminal window with live log feed on startup (configurable)
- **Graceful Shutdown**: Handles signals properly for clean daemon management

## Requirements

- macOS (tested on macOS 12+)
- Administrator privileges (for network configuration changes)
- WiFi interface (default: `en0` - may need adjustment for different Mac models)

## Installation

1. **Clone or download this repository**

2. **Run the installation script**:
   ```bash
   ./install.sh install
   ```

   This will:
   - Make the main script executable
   - Copy the launchd plist to `~/Library/LaunchAgents/`
   - Load the daemon

3. **Start the daemon** (if not already started):
   ```bash
   ./install.sh start
   ```

The daemon will now run in the background and automatically start on each login.

## Usage

### Installation Script Commands

The `install.sh` script provides several commands:

```bash
# Install and load the daemon
./install.sh install

# Uninstall the daemon
./install.sh uninstall

# Check daemon status and view recent logs
./install.sh status

# Start the daemon (if installed)
./install.sh start

# Stop the daemon (if installed)
./install.sh stop
```

### Manual Daemon Management

You can also manage the daemon directly using `launchctl`:

```bash
# Start the daemon
launchctl start com.ghostreconnect.wifi

# Stop the daemon
launchctl stop com.ghostreconnect.wifi

# Unload the daemon
launchctl unload ~/Library/LaunchAgents/com.ghostreconnect.wifi.plist

# Load the daemon
launchctl load ~/Library/LaunchAgents/com.ghostreconnect.wifi.plist

# Check if daemon is running
launchctl list | grep com.ghostreconnect.wifi
```

## Configuration

### Adjusting Check Interval

You can modify the check interval by editing `wifi-reconnect.sh` and changing the `CHECK_INTERVAL` variable:

```bash
CHECK_INTERVAL=${CHECK_INTERVAL:-10}  # Change 10 to your desired interval in seconds
```

Or set it as an environment variable in the plist file.

### Changing WiFi Interface

If your WiFi interface is not `en0`, you can find your interface name by running:

```bash
networksetup -listallhardwareports | grep -A 1 "Wi-Fi"
```

Then update the `WIFI_INTERFACE` variable in `wifi-reconnect.sh`:

```bash
WIFI_INTERFACE="en1"  # Change to your interface name
```

Don't forget to update the plist file path and reinstall after making changes.

### Auto-Open Terminal with Log Feed

By default, the daemon automatically opens a Terminal window with a live log feed (`tail -f`) when it starts. To disable this feature, edit `wifi-reconnect.sh` and change:

```bash
OPEN_LOG_TERMINAL=${OPEN_LOG_TERMINAL:-true}  # Set to false to disable
```

Or set it to `false`:

```bash
OPEN_LOG_TERMINAL=${OPEN_LOG_TERMINAL:-false}
```

After making changes, copy the updated script to `~/bin/` and restart the daemon:

```bash
cp wifi-reconnect.sh ~/bin/wifi-reconnect.sh
launchctl stop com.ghostreconnect.wifi
launchctl start com.ghostreconnect.wifi
```

## How It Works

The daemon continuously monitors three aspects of your WiFi connection:

1. **WiFi Power State**: Checks if WiFi is turned on
2. **Network Association**: Verifies if connected to a WiFi network
3. **Internet Connectivity**: Tests actual internet access using ping

### Reconnection Strategy

When a disconnection is detected, the daemon:

1. If WiFi is off: Turns it on
2. If WiFi is on but not connected: Toggles WiFi (off then on) to force reconnection
3. If connected but no internet: Toggles WiFi to force reconnection
4. Waits for the connection to stabilize before the next check

## Logging

The daemon logs all activities to `/tmp/wifi-reconnect.log`. You can view the logs with:

```bash
# View entire log
cat /tmp/wifi-reconnect.log

# Follow log in real-time
tail -f /tmp/wifi-reconnect.log

# View last 20 lines
tail -n 20 /tmp/wifi-reconnect.log
```

Additional logs are available:
- Standard output: `/tmp/wifi-reconnect.out.log`
- Standard error: `/tmp/wifi-reconnect.err.log`

**Note**: Logs in `/tmp/` are cleared on reboot.

## Troubleshooting

### Daemon Not Starting

1. **Check if the daemon is loaded**:
   ```bash
   launchctl list | grep com.ghostreconnect.wifi
   ```

2. **Check error logs**:
   ```bash
   cat /tmp/wifi-reconnect.err.log
   ```

3. **Verify script permissions**:
   ```bash
   ls -l wifi-reconnect.sh
   # Should show executable permissions: -rwxr-xr-x
   ```

4. **Check plist syntax**:
   ```bash
   plutil -lint ~/Library/LaunchAgents/com.ghostreconnect.wifi.plist
   ```

### WiFi Not Reconnecting

1. **Check the main log**:
   ```bash
   tail -f /tmp/wifi-reconnect.log
   ```

2. **Verify WiFi interface name**:
   ```bash
   networksetup -listallhardwareports | grep -A 1 "Wi-Fi"
   ```
   Update `WIFI_INTERFACE` in `wifi-reconnect.sh` if needed.

3. **Test manual WiFi control**:
   ```bash
   networksetup -setairportpower en0 off
   networksetup -setairportpower en0 on
   ```

4. **Check permissions**: macOS may require administrator approval for network changes. You may see a prompt asking for permission.

### Permission Issues

If you encounter permission errors:

1. **Grant Terminal/Shell full disk access**:
   - System Settings → Privacy & Security → Full Disk Access
   - Add Terminal (or your terminal app)

2. **Grant network configuration permissions**:
   - System Settings → Privacy & Security
   - Look for network-related permissions

3. **Run with sudo** (not recommended for daemon, but for testing):
   ```bash
   sudo networksetup -setairportpower en0 off
   ```

### Daemon Keeps Restarting

If the daemon appears to be restarting frequently:

1. Check error logs for the cause
2. Verify the script path in the plist is correct
3. Ensure the script has proper permissions
4. Check if there are syntax errors in the script

### Uninstalling

To completely remove the daemon:

```bash
./install.sh uninstall
```

This will:
- Stop and unload the daemon
- Remove the plist file from `~/Library/LaunchAgents/`

## File Structure

```
ghostreconnect/
├── wifi-reconnect.sh              # Main monitoring script
├── com.ghostreconnect.wifi.plist  # Launchd configuration
├── install.sh                     # Installation helper script
└── README.md                      # This file
```

## Limitations

- **Polling-based**: Uses polling rather than event-driven detection (simpler but less efficient)
- **Interface assumption**: Defaults to `en0` - may need adjustment for different Mac models
- **Temporary logs**: Logs are stored in `/tmp/` and cleared on reboot
- **macOS-specific**: Uses macOS-specific commands (`networksetup`, `launchctl`)

## Security Considerations

- The script requires network configuration permissions
- macOS may prompt for user approval when making network changes
- The daemon runs with your user privileges (not root)
- Logs may contain network information - review before sharing

## License

This project is provided as-is for personal use.

## Contributing

Feel free to submit issues or pull requests for improvements!
