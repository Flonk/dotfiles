#!/bin/bash

# List VPN connections and use rofi to select one
selected_vpn=$(nmcli connection show | grep vpn | awk -F'  +' '{print $1}' | rofi -i -dmenu -p "Connect VPN")

# Check if a VPN was selected
if [ -z "$selected_vpn" ]; then
    notify-send "VPN Connection" "No VPN selected."
    exit 1
fi

# Connect to the selected VPN
connect_output=$(nmcli connection up "$selected_vpn" 2>&1)

# Check the connection status
if echo "$connect_output" | grep -q "successfully activated"; then
    notify-send "VPN Connection" "Successfully connected to '$selected_vpn'."
else
    error_message=$(echo "$connect_output" | grep -oE 'Error: .*')
    notify-send "VPN Connection" "Failed to connect to '$selected_vpn'. $error_message"
fi
