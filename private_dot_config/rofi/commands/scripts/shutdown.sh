#!/bin/bash

# Define the options
options="shutdown\nreboot\nlogout\nrestart i3"

# Present the options in rofi and store the selection
selected_option=$(echo -e $options | rofi -i -dmenu -p "System:")

# Function to ask for confirmation
confirm_action() {
    echo -e "Yes\nNo" | rofi -i -dmenu -p "Are you sure you want to $1?" -selected-row 1
}

# Perform the selected action
case $selected_option in
    shutdown)
        confirm=$(confirm_action "shutdown")
        if [ "$confirm" == "Yes" ]; then
            shutdown now
        fi
        ;;
    reboot)
        confirm=$(confirm_action "reboot")
        if [ "$confirm" == "Yes" ]; then
            reboot now
        fi
        ;;
    logout)
        confirm=$(confirm_action "logout")
        if [ "$confirm" == "Yes" ]; then
            i3-msg exit
        fi
        ;;
    "restart i3")
        confirm=$(confirm_action "restart i3")
        if [ "$confirm" == "Yes" ]; then
            i3-msg restart
        fi
        ;;
esac
