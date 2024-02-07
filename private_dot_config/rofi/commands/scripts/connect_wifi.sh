#!/bin/bash

# Select the Wi-Fi network
selected_network=$(nmcli dev wifi | awk -F'  +' 'NR>1 && !seen[$3]++ {print $8 " " $3}' | rofi -i -dmenu -p "Connect Wifi" | awk '{print $2}')

# Connect to the selected Wi-Fi network and capture the output
connect_output=$(nmcli dev wifi connect "$selected_network" 2>&1)

# Trim the output to get a concise message
# Adjust the following line according to the output format you want to trim to
concise_message=$(echo "$connect_output" | grep -oE 'successfully activated|failed')

# Use notify-send to display the result
notify-send "Wi-Fi Connection" "$concise_message"
