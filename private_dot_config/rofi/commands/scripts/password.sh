#!/bin/bash

#!/bin/bash

# Check if Bitwarden is unlocked
bw unlock --check

# If the previous command returned non-zero, prompt for password
if [ $? -ne 0 ]; then
    PASSWORD=$(rofi -dmenu -password -p "Enter your Bitwarden password:")

    if [ -z "$PASSWORD" ]; then
        echo "No password entered. Exiting."
        exit 1
    else
        # Unlock Bitwarden and store the session token
        BW_SESSION=$(bw unlock "$PASSWORD" --raw)

        # Check if the unlock was successful
        if [ $? -ne 0 ]; then
            echo "Failed to unlock Bitwarden. Exiting."
            exit 1
        else
            # Export the session token
            export BW_SESSION
            echo "Bitwarden unlocked and BW_SESSION set."
        fi
    fi
else
    echo "Bitwarden is already unlocked."
fi

