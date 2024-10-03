#!/bin/bash

# Color variables
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET='\033[0m'

# Variables
DOWNLOADS_DIR="$HOME/Downloads"
IPSW_FILE_PATH=""
CURRENT_IPSW_PATH=""
IPSW_DOWNLOAD_URL="https://nicsfix.com/ipsw/18.0.ipsw"
BREW_DEPENDENCIES=("libimobiledevice-glue" "libimobiledevice" "libirecovery" "gaster" "ldid-procursus" "tsschecker" "img4tool" "ra1nsn0w")

# Kill any running idevicerestore processes
function kill_idevicerestore() {
    if pgrep idevicerestore >/dev/null; then
        echo -e "${YELLOW}Killing any running idevicerestore processes...${RESET}"
        killall idevicerestore
    fi
}

# Trap CTRL+C and return to the main menu
trap ctrl_c INT

function ctrl_c() {
    echo -e "\n${YELLOW}Process interrupted. Returning to the main menu...${RESET}"
    kill_idevicerestore
    sleep 3
    show_menu
}

# Check Homebrew installation and install dependencies
function check_homebrew() {
    echo -e "${YELLOW}Press CTRL+C at any time to return to the main menu.${RESET}"
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [ $? -eq 0 ]; then
            echo "Homebrew installed successfully."
            USER_HOME=$(eval echo ~$USER)
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$USER_HOME/.profile"
            eval "$(/usr/local/bin/brew shellenv)"
            echo "Homebrew environment set up for the current session."
        else
            echo "Homebrew installation failed. Exiting."
            exit 1
        fi
    else
        echo "Homebrew is already installed."
    fi
    install_dependencies
    echo "Returning to the main menu..."
    sleep 3
    show_menu
}

# Spinner function for process wait times
function spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\\'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "\b\b\b\b\b\b"
}

# Install dependencies, including head-only formulas
function install_dependencies() {
    echo -e "${YELLOW}Press CTRL+C at any time to return to the main menu.${RESET}"
    echo "Tapping d235j/ios-restore-tools..."
    brew tap d235j/ios-restore-tools

    # Install idevicerestore latest version
    brew install idevicerestore

    # Install the regular dependencies
    for dep in "${BREW_DEPENDENCIES[@]}"; do
        if ! brew list "$dep" &> /dev/null; then
            echo "Installing $dep..."
            brew install "$dep"
        else
            echo "$dep is already installed."
        fi
    done

    # Install head-only formulas explicitly
    echo "Installing head-only formulas..."

    # Install gaster (head-only)
    if ! brew list gaster &> /dev/null; then
        echo "Installing gaster..."
        brew install --HEAD d235j/ios-restore-tools/gaster
    else
        echo "gaster is already installed."
    fi

    # Install tsschecker (head-only)
    if ! brew list tsschecker &> /dev/null; then
        echo "Installing tsschecker..."
        brew install --HEAD d235j/ios-restore-tools/tsschecker
    else
        echo "tsschecker is already installed."
    fi

    # Install img4tool (head-only)
    if ! brew list img4tool &> /dev/null; then
        echo "Installing img4tool..."
        brew install --HEAD d235j/ios-restore-tools/img4tool
    else
        echo "img4tool is already installed."
    fi

    # Install ra1nsn0w (head-only)
    if ! brew list ra1nsn0w &> /dev/null; then
        echo "Installing ra1nsn0w..."
        brew install --HEAD d235j/ios-restore-tools/ra1nsn0w
    else
        echo "ra1nsn0w is already installed."
    fi
}

# Prompt for IPSW path
function prompt_for_ipsw_path() {
    echo "Please drag and drop the IPSW file into this window and press Enter."
    read -r IPSW_FILE_PATH
    if [[ ! -f "$IPSW_FILE_PATH" ]]; then
        echo "File does not exist at $IPSW_FILE_PATH. Please check the path and try again."
        prompt_for_ipsw_path
    else
        echo "IPSW file path stored: $IPSW_FILE_PATH"
        update_script_with_ipsw_path "$IPSW_FILE_PATH"
    fi
}

# Update the script with the new IPSW file path
function update_script_with_ipsw_path() {
    local new_path="$1"
    escaped_new_path=$(printf '%s' "$new_path" | sed 's/[&/\]/\\&/g')
    sed -i '' "s|^CURRENT_IPSW_PATH=.*|CURRENT_IPSW_PATH=\"$escaped_new_path\"|" "$0"
    CURRENT_IPSW_PATH="$new_path"
    echo -e "${GREEN}IPSW file path successfully updated to: $new_path${RESET}"
}

# Download IPSW
function download_ipsw() {
    SCRIPT_DIR=$(dirname "$(realpath "$0")")
    IPSW_DEST_PATH="$SCRIPT_DIR/audioOS.ipsw"
    if [[ -f "$IPSW_DEST_PATH" ]]; then
        echo -e "${YELLOW}IPSW file already exists at $IPSW_DEST_PATH. Skipping download...${RESET}"
        update_script_with_ipsw_path "$IPSW_DEST_PATH"
    else
        echo -e "${YELLOW}Downloading the IPSW file...${RESET}"
        curl -L -C - "$IPSW_DOWNLOAD_URL" -o "$IPSW_DEST_PATH" --progress-bar
        if [[ $? -ne 0 ]]; then
            echo -e "${YELLOW}Failed to download the IPSW file. Please check your connection.${RESET}"
        else
            echo -e "${GREEN}Download complete! IPSW saved to: $IPSW_DEST_PATH${RESET}"
            update_script_with_ipsw_path "$IPSW_DEST_PATH"
        fi
    fi
    echo "Returning to the main menu..."
    sleep 15
    show_menu
}

# Update IPSW path
function update_ipsw_path() {
    echo "Updating the IPSW file location..."
    prompt_for_ipsw_path
    echo "IPSW path updated successfully."
    echo -e "${YELLOW}Returning to the main menu...${RESET}"
    sleep 3
    show_menu
}

# Get IPSW path
function get_ipsw_path() {
    if [[ -z "$CURRENT_IPSW_PATH" || ! -f "$CURRENT_IPSW_PATH" ]]; then
        echo "No valid IPSW file path found. Please provide the IPSW file path."
        prompt_for_ipsw_path
    else
        echo -e "${GREEN}Using stored IPSW file path: $CURRENT_IPSW_PATH${RESET}"
    fi
}

# Check if a device is connected in DFU mode
function check_device_in_dfu() {
    echo -e "${YELLOW}Checking if a HomePod is connected in DFU mode... This may take up to 10 seconds.${RESET}"
    device_info=$(irecovery -q 2>&1)
    if echo "$device_info" | grep -q "ERROR: Unable to connect to device"; then
        echo -e "${RED}No device detected in DFU mode. Please connect your HomePod in DFU mode and try again.${RESET}"
        return 1
    else
        echo -e "${GREEN}HomePod detected in DFU mode.${RESET}"
        return 0
    fi
}

# Restore the HomePod
function restore_homepod() {
    echo -e "${YELLOW}Starting HomePod restore process... Press CTRL+C at any time to return to the main menu.${RESET}"
    check_device_in_dfu
    if [[ $? -ne 0 ]]; then
        sleep 3
        show_menu
        return
    fi
    get_ipsw_path
    if [[ ! -f "$CURRENT_IPSW_PATH" ]]; then
        echo "Error: IPSW file not found at $CURRENT_IPSW_PATH. Please update the IPSW file location."
        update_script_with_ipsw_path
        return
    fi

    SCRIPT_DIR=$(dirname "$(realpath "$0")")
    RESTORE_LOG="$SCRIPT_DIR/restore_log_$(date +%Y%m%d_%H%M%S).txt"
    echo -e "${YELLOW}Logging full output to $RESTORE_LOG${RESET}"

    gaster pwn >> "$RESTORE_LOG" 2>&1
    gaster reset >> "$RESTORE_LOG" 2>&1

    echo -e "${YELLOW}Restore process started. Follow these checkpoints.${RESET}"
    idevicerestore -d -e "$CURRENT_IPSW_PATH" >> "$RESTORE_LOG" 2>&1 &
    RESTORE_PID=$!
    
    spinner $RESTORE_PID &

    CHECKPOINT_1=false
    CHECKPOINT_2=false
    CHECKPOINT_3=false
    CHECKPOINT_4=false
    CHECKPOINT_5=false
    CHECKPOINT_6=false
    CHECKPOINT_7=false

    while kill -0 $RESTORE_PID 2> /dev/null; do
        sleep 3  
        LAST_LOG_LINES=$(tail -n 100 "$RESTORE_LOG")

        if echo "$LAST_LOG_LINES" | grep -q "Now you can boot untrusted images." && [ "$CHECKPOINT_1" = false ]; then
            echo -e "${GREEN}Checkpoint 1: Connected to HomePod${RESET}"
            CHECKPOINT_1=true
        fi
        if echo "$LAST_LOG_LINES" | grep -q "Extracting filesystem from IPSW: myrootfs.dmg" && [ "$CHECKPOINT_2" = false ]; then
            echo -e "${GREEN}Checkpoint 2: Opening IPSW${RESET}"
            CHECKPOINT_2=true
        fi
        if echo "$LAST_LOG_LINES" | grep -q "NOTE        : No path for component iBEC in TSS, will fetch from build_identity" && [ "$CHECKPOINT_3" = false ]; then
            echo -e "${GREEN}Checkpoint 3: Entering Recovery Mode${RESET}"
            CHECKPOINT_3=true
        fi
        if echo "$LAST_LOG_LINES" | grep -q "BoardID: 56" && [ "$CHECKPOINT_4" = false ]; then
            echo -e "${GREEN}Checkpoint 4: NAND Check${RESET}"
            CHECKPOINT_4=true
        fi
        if echo "$LAST_LOG_LINES" | grep -q "Validating the filesystem" && [ "$CHECKPOINT_5" = false ]; then
            echo -e "${GREEN}Checkpoint 5: Validating Filesystem${RESET}"
            CHECKPOINT_5=true
        fi
        if echo "$LAST_LOG_LINES" | grep -q "Restoring image (13)" && [ "$CHECKPOINT_6" = false ]; then
            echo -e "${GREEN}Checkpoint 6: Restoring HomePod, this takes 10-15 minutes. Check log for detailed progress.${RESET}"
            CHECKPOINT_6=true
        fi
        if echo "$LAST_LOG_LINES" | grep -q "(check_mounted) result=0" && [ "$CHECKPOINT_7" = false ]; then
            echo -e "${GREEN}Checkpoint 7: Restore complete. Wait until this message disappears to unplug power from HomePod, turn right-side up and plug back in. Set up as normal.${RESET}"
            CHECKPOINT_7=true
            sleep 45
            echo -e "${YELLOW}Returning to the main menu...${RESET}"
            sleep 3
            show_menu
        fi

        if echo "$LAST_LOG_LINES" | grep -q "ERROR: Device did not reconnect in recovery mode. Possibly invalid iBEC" || echo "$LAST_LOG_LINES" | grep -q "ERROR: Unable to place device into recovery mode from DFU mode"; then
            echo -e "${RED}Unable to place device into recovery mode. This could be due to a hardware fault.${RESET}"
            echo -e "${YELLOW}Unplug the HomePod from power and try again. If you see this error repeatedly, you likely have a hardware failure.${RESET}"
            sleep 15
            show_menu
        fi
    done

    wait $RESTORE_PID
    RESTORE_EXIT_CODE=$?

    kill $! 2>/dev/null  
    printf "\n"

    if [ "$RESTORE_EXIT_CODE" -ne 0 ] && [ "$CHECKPOINT_7" = false ]; then
        echo -e "${YELLOW}Restore process encountered issues. Please check the full log: $RESTORE_LOG${RESET}"
    else
        echo -e "${GREEN}Restore process completed successfully. Full log saved: $RESTORE_LOG${RESET}"
    fi

    show_menu
}

# Function to update the script with the latest version
function update_script() {
    echo -e "${YELLOW}Checking for script updates...${RESET}"
    SCRIPT_URL="https://raw.githubusercontent.com/anon1y4012/HomePodRestore/main/restorer.sh"
    TEMP_SCRIPT="/tmp/latest_homepod_restore_script.sh"
    curl -L -o "$TEMP_SCRIPT" "$SCRIPT_URL"

    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Failed to download the latest script. Please check your connection or the URL.${RESET}"
        sleep 3
        show_menu
        return
    fi

    chmod +x "$TEMP_SCRIPT"
    mv "$TEMP_SCRIPT" "$0"
    echo -e "${GREEN}Script updated successfully. Restarting...${RESET}"
    sleep 5
    exec "$0"
}

# Function to create a custom IPSW
function create_custom_ipsw() {
    echo -e "${YELLOW}Creating custom IPSW...${RESET}"
    MAKEIPSW_SCRIPT_URL="https://raw.githubusercontent.com/tihmstar/homepodstuff/main/makeipsw.sh"
    SCRIPT_DIR=$(dirname "$(realpath "$0")")
    MAKEIPSW_SCRIPT="$SCRIPT_DIR/makeipsw.sh"

    echo -e "${YELLOW}Downloading makeipsw.sh...${RESET}"
    curl -L -o "$MAKEIPSW_SCRIPT" "$MAKEIPSW_SCRIPT_URL"
    chmod +x "$MAKEIPSW_SCRIPT"

    echo -e "${YELLOW}Please drag and drop the OTA file (.zip format) into this window and press Enter.${RESET}"
    read -r OTA_FILE_PATH
    OTA_FILE_PATH=$(echo "$OTA_FILE_PATH" | sed 's/\\//g')
    OTA_EXTENSION="${OTA_FILE_PATH##*.}"

    if [[ "$OTA_EXTENSION" != "zip" ]]; then
        echo -e "${RED}Invalid OTA file. Must be a .zip file.${RESET}"
        return
    fi

    echo -e "${YELLOW}Please drag and drop the firmware keys file (.zip format) into this window and press Enter.${RESET}"
    read -r KEYS_FILE_PATH
    KEYS_FILE_PATH=$(echo "$KEYS_FILE_PATH" | sed 's/\\//g')
    KEYS_EXTENSION="${KEYS_FILE_PATH##*.}"

    if [[ "$KEYS_EXTENSION" != "zip" ]]; then
        echo -e "${RED}Invalid firmware keys file. Must be a .zip file.${RESET}"
        return
    fi

    echo -e "${YELLOW}Please drag and drop the base IPSW file (.ipsw format) into this window and press Enter.${RESET}"
    read -r IPSW_FILE_PATH
    IPSW_FILE_PATH=$(echo "$IPSW_FILE_PATH" | sed 's/\\//g')
    IPSW_EXTENSION="${IPSW_FILE_PATH##*.}"

    if [[ "$IPSW_EXTENSION" != "ipsw" ]]; then
        echo -e "${RED}Invalid IPSW file. Must be a .ipsw file.${RESET}"
        return
    fi

    OUTPUT_IPSW="$SCRIPT_DIR/custom_homepod_restore.ipsw"
    echo -e "${YELLOW}Running makeipsw.sh to create the custom IPSW...${RESET}"
    "$MAKEIPSW_SCRIPT" "$OTA_FILE_PATH" "$IPSW_FILE_PATH" "$OUTPUT_IPSW" "$KEYS_FILE_PATH"

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Custom IPSW created successfully at: $OUTPUT_IPSW${RESET}"
        echo -e "${YELLOW}Updating IPSW path to: $OUTPUT_IPSW${RESET}"
        update_script_with_ipsw_path "$OUTPUT_IPSW"
    else
        echo -e "${RED}Failed to create custom IPSW. Please check the inputs and try again.${RESET}"
    fi

    echo -e "${YELLOW}Returning to the main menu...${RESET}"
    sleep 5
    show_menu
}

# Main menu display
function show_menu() {
    kill_idevicerestore
    clear
    echo -e "\033[1m==============================\033[0m"
    echo -e "\033[1m||   HomePod Restore Tool   ||\033[0m"
    echo -e "\033[1m==============================\033[0m"
    echo ""
    echo -e "\033[4mPlease choose an option:\033[0m"
    echo ""
    echo "1) Check/Install Dependencies"
    echo "2) Restore HomePod"
    echo "3) Create a Custom IPSW"
    echo "4) Update IPSW File Location"
    echo "5) Download Pre-built IPSW"
    echo "6) Update This Script"
    echo "7) Exit"
    echo -e "${GREEN}Many thanks to David Ryskalczyk and tihmstar for the tools used in this project. If you'd like to support tihmstar, consider becoming a Patron.${RESET}"
    echo "█████████████████████████████████"
    echo "█████████████████████████████████"
    echo "████ ▄▄▄▄▄ █▀▀█ ▀   ██ ▄▄▄▄▄ ████"
    echo "████ █   █ █▄█ ▀ █ ▀██ █   █ ████"
    echo "████ █▄▄▄█ █ ▀█▄▀█▄ ▄█ █▄▄▄█ ████"
    echo "████▄▄▄▄▄▄▄█ ▀▄▀ █▄█ █▄▄▄▄▄▄▄████"
    echo "████ ▄▀ █▀▄▄█ ▀█ ▄██▀█ ▄▄█▄▄▀████"
    echo "████ ▀ █ ▄▄▄█ ██▄▀▀▀▀  █▀██▄▄████"
    echo "█████ ███▀▄█ ▀ ▄ ▄███▄  █ ▀▄ ████"
    echo "████▄▀▄ ▄ ▄ █ ▀ █ ▀▀██ ▄ █▄▀▄████"
    echo "████▄▄▄▄▄▄▄▄▀▄▄  █▀▀ ▄▄▄  ▄█▀████"
    echo "████ ▄▄▄▄▄ █▄▄▀▀ ▄▀▄ █▄█  ▀ ▄████"
    echo "████ █   █ █▀▀ ▄▀▄▄▀▄ ▄   ▀  ████"
    echo "████ █▄▄▄█ █▀▄█▀▀ ██▀▀▀▄▄▀▄█▄████"
    echo "████▄▄▄▄▄▄▄█▄▄█▄▄▄▄▄▄██▄███▄▄████"
    echo "█████████████████████████████████"
    echo "█████████████████████████████████"

    read -p "Enter Selection [1-7]: " choice

    case $choice in
        1)
            check_homebrew
            install_dependencies
            ;;
        2)
            restore_homepod
            ;;
        3)
            create_custom_ipsw
            ;;
        4)
            update_ipsw_path
            ;;
        5)
            download_ipsw
            ;;
        6)
            update_script
            ;;
        7)
            kill_idevicerestore
            echo "Exiting script..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            show_menu
            ;;
    esac
}

show_menu