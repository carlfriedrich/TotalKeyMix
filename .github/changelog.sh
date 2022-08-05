#!/bin/bash

url=$(git remote get-url origin | sed "s/.git$//g")

previous_tag=$(git describe --tags --abbrev=0 HEAD~)

echo "Changes since $previous_tag:"
echo

# Loop through all commits since previous tag
for rev in $(git log $previous_tag..HEAD --format="%H")
do
    summary=$(git log $rev~..$rev --format="%s")
    # Exclude commits starting with "Meta"
    if [[ $summary != Meta* ]]
    then
        # Print markdown list of commit headlines
        echo "* [$summary]($url/commit/$rev)"
        # Append commit body indented (blank lines removed)
        git log $rev~..$rev --format="%b" | sed '/^$/d' | while read -r line
        do
            echo "  $line"
        done
    fi
done
