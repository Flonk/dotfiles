#!/bin/bash

# Get a list of active VPN connections
active_vpns=$(nmcli connection show --active | grep vpn | awk '{print $1}')

# Check if there are any active VPN connections
if [ -z "$active_vpns" ]; then
    notify-send "VPN Disconnection" "No active VPN connections found."
    exit 0
fi

# Loop through each active VPN and disconnect
while read -r vpn; do
    disconnect_output=$(nmcli connection down "$vpn" 2>&1)

    # Check the disconnection status
    if echo "$disconnect_output" | grep -q "successfully deactivated"; then
        notify-send "VPN Disconnection" "Successfully disconnected from '$vpn'."
    else
        error_message=$(echo "$disconnect_output" | grep -oE 'Error: .*')
        notify-send "VPN Disconnection" "Failed to disconnect from '$vpn'. $error_message"
    fi
done <<< "$active_vpns"
