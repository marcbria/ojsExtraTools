#!/bin/bash

# ==============================================================================
# Title:          OJS Upgrade Script
# Author:         Marc Bria
# Date:           2025/03/30
# Description:    Automates the upgrade process for Open Journal Systems (OJS)
#                 using the docker-ojs project. Ensure the following directories
#                 contain the appropriate files before running:
#                   - volumes/dump: Database dump file
#                   - volumes/public: Public files
#                   - volumes/private: Private files
# WARNING:        This script will overwrite important files in your installation.
#                 Make a backup of your OJS before running it.
# Usage:          sudo ./dockgradeMe.sh <containerName> [interactive] [domain] [upgradePath] [mysqlPwd]
#                   - containerName: (Required) Docker container name.
#                   - interactive:   (Optional) 1 interactive, 0 for batch.
#                   - domain:        (Optional) URL to override PROJECT_DOMAIN.
#                   - upgradePath:   (Optional) Versions override for UPGRADE_PATH.
#                   - mysqlPwd:      (Optional) New MySQL password.
# Dependencies:   docker-ojs project, curl, docker, docker-compose, sed
# License:        GPL-3.0
# ==============================================================================

# Check if the script is running with sudo (root privileges)
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run with sudo (root) privileges."
    echo "Usage: sudo ./dockgradeMe.sh <containerName> [interactive] [domain] [upgradePath] [mysqlPwd]"
    exit 1
fi

# Default Configuration (could be overwritten by params)
UPGRADE_PATH="2_4_8-5 stable-3_2_1 stable-3_3_0"
INTERACTIVE=1
LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/$(date +'%Y%m%d-%H%M')-dockgrade.log"  # Log file format changed
ENV_FILE=".env"
CONFIG_FILE="./volumes/config/ojs.config.inc.php"

logMessage() {
    echo "$(date +'%H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

errorExit() {
    logMessage "====================================================================="
    logMessage "Failed to upgrade at stage: $1"
    logMessage "====================================================================="
    exit 1
}

updateEnvVariable() {
    local varName=$1
    local newValue=$2
    if grep -q "^${varName}=" "$ENV_FILE"; then
        sed -i "s|^${varName}=.*|${varName}=${newValue}|" "$ENV_FILE"
        # echo "DEBUG: Replace [$varName] with [$newValue]"
    else
        echo "${varName}=${newValue}" >> "$ENV_FILE"
        # echo "DEBUG: Setting [$varName] with [$newValue]"
    fi
}

updateConfigVariable() {
    local varName=$1
    local newValue=$2
    sed -i "s|^${varName} = .*|${varName} = ${newValue}|" "$CONFIG_FILE"
}

fixPermissions() {
    # Set in general first for www-data user and 744.
    chown 100:101 ./volumes -Rf
    chmod 744 ./volumes -Rf

    # Change for DB volumes
    chown 999:1002 ./volumes/db -Rf
    chown 999:1002 ./volumes/dump -Rf
}

raiseAdminer() {
    docker exec -it ojs_app_$containerName \
	wget -q https://github.com/vrana/adminer/releases/download/v5.0.1/adminer-5.0.1-en.php -O /var/www/html/dbcheck.php || echo "--> Warning: Unable to download adminer. "
}

clearCache() {
    docker exec -it ojs_app_$containerName sh -c \
	    "find /var/www/html/cache -type f -delete"
}

main() {
    if [ -z "$1" ]; then
        echo "Error: The parameter 'containerName' is required."
        echo "Usage: sudo ./dockgradeMe.sh <containerName> [interactive] [domain] [upgradePath] [mysqlPwd]"
        exit 1
    fi

    containerName=$1
    interactive=${2:-$INTERACTIVE}
    domain=$3
    upgradePath=${4:-$UPGRADE_PATH}
    mysqlPwd=$5

    # Update environment variables
    VERSION="Preparation"

    logMessage "Downloading .env.TEMPLATE"
    curl -fsSL "https://raw.githubusercontent.com/pkp/docker-ojs/main/.env.TEMPLATE" -o "$ENV_FILE" || { logMessage "Error downloading .env.TEMPLATE"; errorExit "$PREPARATION"; }

    updateEnvVariable "COMPOSE_PROJECT_NAME" "$containerName"

    if [ -n "$domain" ]; then
        updateEnvVariable "PROJECT_DOMAIN" "$domain"
    fi

    if [ -n "$mysqlPwd" ]; then
        updateEnvVariable "MYSQL_ROOT_PASSWORD" "$mysqlPwd"
        updateEnvVariable "OJS_DB_PASSWORD" "$mysqlPwd"
    fi

    mkdir -p "$LOG_DIR"


    # Make the same process for each version in the UPGRADE_PATH

    for VERSION in $upgradePath; do
        logMessage "Starting upgrade to version: $VERSION"

        updateEnvVariable "OJS_VERSION" "$VERSION"

        set -a
        source "$ENV_FILE"
        set +a

        # Check if version is less than "3_1_2-4" and modify the URL accordingly
        if [ "$(printf '%s\n' "$VERSION" "3_1_2-4" | sort -V | head -n1)" != "3_1_2-4" ]; then
            CONFIG_URL="https://github.com/pkp/ojs/raw/ojs-${OJS_VERSION}/config.TEMPLATE.inc.php"
        else
            CONFIG_URL="https://github.com/pkp/ojs/raw/${OJS_VERSION}/config.TEMPLATE.inc.php"
        fi

	# logMessage "Remove OJS config file (if any) as it needs to fit with OJS version"
	# rm ./volumes/config/ojsconfig.inc
        logMessage "Downloading config.TEMPLATE.inc.php for version $OJS_VERSION from $CONFIG_URL"
        curl -fsSL "$CONFIG_URL" -o "$CONFIG_FILE" || { logMessage "Error downloading config.TEMPLATE.inc.php"; errorExit "$VERSION"; }
	echo -e "\n;;; Config file for version: $VERSION" >> $CONFIG_FILE

        updateConfigVariable "installed" "On"
        updateConfigVariable "base_url" "\"${domain}\""

        updateConfigVariable "host" "$OJS_DB_HOST"
        updateConfigVariable "password" "$OJS_DB_PASSWORD"
        updateConfigVariable "files_dir" "/var/www/files"

	# Upgrade Specific variables: Replace when necessary.
        # updateConfigVariable "display_errors" "On"

        updateConfigVariable "encryption" "sha1"
        updateConfigVariable "oai" "On"

        updateConfigVariable "locale" "pt_BR"
        updateConfigVariable "client_charset" "utf-8"
        updateConfigVariable "charset_normalization" "On"
        updateConfigVariable "connection_charset" "utf8"
        updateConfigVariable "database_charset" "utf8"
        # updateConfigVariable "charset" "utf8mb4"

	# Notice we didn't touch the mysql driver. 
	# It needs to be mysql or mysqli based on version you use, so the versioned config we download will include the right one. 

        logMessage "Adjusting permissions for volumes"
	fixPermissions

        logMessage "Stopping and starting the Docker stack"
        docker compose down
        docker compose up -d || { logMessage "Error restarting Docker stack"; errorExit "$VERSION"; }

	logMessage "Loading DB dump (if any)..."
	logMessage "Waiting the DB container to be ready..."

	while ! docker compose logs --no-color 2>&1 | grep -q '\[Note\] mysqld: ready for connections'; do
	  sleep 1
	done

        logMessage "✅ The DB is ready for connections."

	logMessage "Raising an adminer to help checking the DB (https://localhost/dbcheck.php)"
	raiseAdminer

	read -p "CHECK your DB (up, credentials, charset)  and press any key to run the upgrade to $VERSION..."

        logMessage "UPGRADE $VERSION: Running the upgrade..."
        docker compose exec -T ojs php tools/upgrade.php check | tee -a "$LOG_FILE"

        # Show intermediate message after each version upgrade
        logMessage "The journal has been updated to the intermediate version: $VERSION."
        logMessage "You can visit it at: $domain"
        logMessage "You can view the logs at: $LOG_FILE"
        
        logMessage "Executing the OJS upgrade"
        docker compose exec -T ojs php tools/upgrade.php upgrade | tee -a "$LOG_FILE"

        if grep -q "Successfully upgraded" "$LOG_FILE"; then
            logMessage "Upgrade to version $VERSION completed successfully."
        else
            { logMessage "Upgrade failed for version $VERSION"; errorExit "$VERSION"; }
        fi

        if [ "$interactive" -eq 1 ]; then
            read -p "Accept if everything is correct and you want to continue with NEXT upgrade. (y/n): " response
            if [ "$response" != "y" ]; then
                logMessage "Upgrade canceled by user at [$VERSION] stage."
                exit 0
            fi
        fi

	logMessage "Cleaning Cache"
	clearCache

    done

    echo ""
    logMessage "Reindex de DB (be sure you install and config pdftotext)..."
    docker compose exec -T ojs php tools/rebuildSearchIndex.php | tee -a "$LOG_FILE"

    logMessage "==========================================================================="
    logMessage "Upgrade process completed Successfully !!"
    logMessage "> Upgrade path executed: $upgradePath"
    logMessage "> Visit: $domain"
    logMessage "==========================================================================="
}

main "$@"
