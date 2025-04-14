#!/bin/sh

# Show script usage syntax
showUsage() {
    echo "Usage: $0 <mergeDestination> <userListFile>"
    exit 1
}

# Check if a file exists and is readable
checkFileReadable() {
    filePath="$1"
    if [ ! -r "$filePath" ]; then
        echo "Error: Cannot read file '$filePath'."
        exit 1
    fi
}

# Count non-empty lines in a file
countNonEmptyLines() {
    filePath="$1"
    grep -cve '^[[:space:]]*$' "$filePath"
}

# Check if destination user is invalid in merge output
isInvalidDestinationUser() {
    output="$1"
    destUser="$2"
    echo "$output" | grep -q "Error: \"$destUser\" does not specify a valid user."
    return $?
}

# Execute merge operation for a single user
executeMerge() {
    destUser="$1"
    sourceUser="$2"
    scriptPath="$3"

    php "$scriptPath" "$destUser" "$sourceUser" 2>&1
}

# Perform merges and track progress
processUserList() {
    destUser="$1"
    listFile="$2"
    scriptPath="$3"

    totalMerges=`countNonEmptyLines "$listFile"`
    if [ "$totalMerges" -eq 0 ]; then
        echo "No valid usernames found in '$listFile'."
        exit 1
    fi

    mergeSuccess=0
    mergeFails=0
    currentMerge=1

    while IFS= read -r username
    do
        if [ -z "$username" ]; then
            continue
        fi

        echo "[$currentMerge/$totalMerges] Merging user '$username' into '$destUser'..."

        output=`executeMerge "$destUser" "$username" "$scriptPath"`
        exitCode=$?

        isInvalidDestinationUser "$output" "$destUser"
        if [ $? -eq 0 ]; then
            echo "Destination user '$destUser' does not exist. Process stopped."
            exit 1
        fi

        if [ "$exitCode" -eq 0 ]; then
            mergeSuccess=`expr "$mergeSuccess" + 1`
        else
            mergeFails=`expr "$mergeFails" + 1`
        fi

        currentMerge=`expr "$currentMerge" + 1`

    done < "$listFile"

    echo "Merge completed. Success: $mergeSuccess, Failures: $mergeFails"
}

# Main entry point
main() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        showUsage
    fi

    mergeDestination="$1"
    userListFile="$2"
    mergeScript="/var/www/html/tools/mergeUsers.php"

    checkFileReadable "$userListFile"
    checkFileReadable "$mergeScript"

    processUserList "$mergeDestination" "$userListFile" "$mergeScript"
}

main "$@"
