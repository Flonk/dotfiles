#!/bin/bash

# Configurable variables
FILE_EXTENSION="kt"
ROOT_FOLDER="src/main"

# Get the current branch name
current_branch=$(git branch --show-current)

# Iterate through each commit in the current branch
git rev-list $current_branch | while read commit_hash; do
  # Checkout the commit
  git checkout $commit_hash --quiet

  # Extract ticket number from the commit message
  ticket_number=$(git log -1 --pretty=%B | grep -oE '(RKU|TIAAS)-[0-9]+')

  # Extract commit date in ISO format
  commit_date=$(git log -1 --pretty=format:%cI)

  # Count lines of code in the root folder
  loc=$(find $ROOT_FOLDER -type f -name "*.$FILE_EXTENSION" | xargs cat | wc -l)

  # Print the result if a ticket number is found
  if [ -n "$ticket_number" ]; then
    echo "$ticket_number, $commit_date, $loc"
  fi
done

# Checkout back to the original branch
git checkout $current_branch --quiet

echo "Processing complete"
