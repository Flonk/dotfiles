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
    Shutdown)
        confirm=$(confirm_action "shutdown")
        if [ "$confirm" == "Yes" ]; then
            systemctl poweroff
        fi
        ;;
    Reboot)
        confirm=$(confirm_action "reboot")
        if [ "$confirm" == "Yes" ]; then
            systemctl reboot
        fi
        ;;
    Logout)
        confirm=$(confirm_action "logout")
        if [ "$confirm" == "Yes" ]; then
            i3-msg exit
        fi
        ;;
    "Restart i3")
        confirm=$(confirm_action "restart i3")
        if [ "$confirm" == "Yes" ]; then
            i3-msg restart
        fi
        ;;
esac
