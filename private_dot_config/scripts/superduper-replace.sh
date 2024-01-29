#!/bin/bash

# A file contains a line-based json with key/number pairs. iterate over an entire
# repository and do search/replace for all pairs.

# Path to your JSON file
JSON_FILE="./map2.json"

# Path to your repository or directory where you want to perform search and replace
REPO_PATH="~/repos/blalbal"

# Read each JSON object from the file
while IFS= read -r line; do
    # Use jq to parse each line as a separate JSON object
    KEY=$(echo $line | jq -r '.key')
    NUMBER=$(echo $line | jq -r '.number')

    # Perform search and replace
    grep -rl --exclude-dir=.git "$KEY" $REPO_PATH | xargs sed -i "s/$KEY/$NUMBER/g"
done < "$JSON_FILE"
