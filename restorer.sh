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

# Variables
BREW_DEPENDENCIES=("libimobiledevice-glue" "libimobiledevice" "libirecovery" "gaster" "ldid-procursus" "tsschecker" "img4tool" "ra1nsn0w" "qrencode")
SPECIFIC_IDEVICERESTORE_REVISION="d2e1c4f"  # The specific revision you want to install

# Function to install specific revision of idevicerestore
function install_specific_idevicerrestore_revision() {
    echo -e "${YELLOW}Installing specific idevicerestore revision (${SPECIFIC_IDEVICERESTORE_REVISION})...${RESET}"
    
    # Get the formula file path for idevicerestore
    FORMULA_PATH=$(brew --repo d235j/homebrew-ios-restore-tools)/Formula/idevicerestore.rb

    # Check if the formula exists
    if [[ -f "$FORMULA_PATH" ]]; then
        echo "Found idevicerestore.rb at $FORMULA_PATH"
        
        # Replace the head reference with the specific commit
        sed -i '' 's|head "https://github.com/libimobiledevice/idevicerestore.git"|head "https://github.com/libimobiledevice/idevicerestore.git", revision: "d2e1c4f"|' "$FORMULA_PATH"
        
        # Uninstall current version of idevicerestore
        brew uninstall idevicerestore --ignore-dependencies
        
        # Install the specific idevicerestore revision
        brew install --HEAD idevicerestore
    else
        echo -e "${RED}Failed to locate idevicerestore formula file. Ensure the Homebrew tap is installed.${RESET}"
    fi
}

# Function to trap CTRL+C and return to the main menu
trap ctrl_c INT

# CTRL+C handler to return to the main menu
function ctrl_c() {
    echo -e "\n${YELLOW}Process interrupted. Returning to the main menu...${RESET}"
    sleep 3
    show_menu
}

# Functions
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


# Function to install dependencies
function install_dependencies() {
    echo -e "${YELLOW}Press CTRL+C at any time to return to the main menu.${RESET}"
    echo "Tapping d235j/ios-restore-tools..."
    brew tap d235j/ios-restore-tools

    # Install the specific idevicerestore revision
    install_specific_idevicerrestore_revision

    # Install the rest of the dependencies including qrencode
    for dep in "${BREW_DEPENDENCIES[@]}"; do
        if ! brew list $dep &> /dev/null; then
            echo "Installing $dep..."
            brew install "$dep"
        else
            echo "$dep is already installed."
        fi
    done
}

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

# Function to update the script with the new IPSW file path
function update_script_with_ipsw_path() {
    local new_path="$1"
    
    # Escape slashes and other special characters in the file path for sed
    escaped_new_path=$(printf '%s' "$new_path" | sed 's/[&/\]/\\&/g')

    # Use sed to replace the CURRENT_IPSW_PATH with the new path
    sed -i '' "s|^CURRENT_IPSW_PATH=.*|CURRENT_IPSW_PATH=\"$escaped_new_path\"|" "$0"
    
    # Update the global variable for the current session
    CURRENT_IPSW_PATH="$new_path"
    
    echo -e "${GREEN}IPSW file path successfully updated to: $new_path${RESET}"
}

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

function update_ipsw_path() {
    echo "Updating the IPSW file location..."
    prompt_for_ipsw_path
    echo "IPSW path updated successfully."
    echo -e "${YELLOW}Returning to the main menu...${RESET}"
    sleep 3
    show_menu
}

function get_ipsw_path() {
    if [[ -z "$CURRENT_IPSW_PATH" || ! -f "$CURRENT_IPSW_PATH" ]]; then
        echo "No valid IPSW file path found. Please provide the IPSW file path."
        prompt_for_ipsw_path
    else
        echo -e "${GREEN}Using stored IPSW file path: $CURRENT_IPSW_PATH${RESET}"
    fi
}

function check_device_in_dfu() {
    echo -e "${YELLOW}Checking if a HomePod is connected in DFU mode... This may take up to 10 seconds.${RESET}"
    
    # Run irecovery with a timeout and capture the output
    device_info=$(irecovery -q 2>&1)

    # Check for specific error message
    if echo "$device_info" | grep -q "ERROR: Unable to connect to device"; then
        echo -e "${RED}No device detected in DFU mode. Please connect your HomePod in DFU mode and try again.${RESET}"
        return 1  # Return error code 1 if no device is found
    else
        echo -e "${GREEN}HomePod detected in DFU mode.${RESET}"
        return 0  # Return success code 0 if the device is found
    fi
}

# Function to restore the HomePod
function restore_homepod() {
    echo -e "${YELLOW}Starting HomePod restore process... Press CTRL+C at any time to return to the main menu.${RESET}"

    # Check if the device is connected in DFU mode
    check_device_in_dfu
    if [[ $? -ne 0 ]]; then
        sleep 3
        show_menu  # Return to the main menu if the device is not detected
        return
    fi

    # Ensure IPSW file path is set and valid
    get_ipsw_path

    if [[ ! -f "$CURRENT_IPSW_PATH" ]]; then
        echo "Error: IPSW file not found at $CURRENT_IPSW_PATH. Please update the IPSW file location."
        update_script_with_ipsw_path
        return
    fi

    # Log file setup, and continue with gaster commands, idevicerestore, etc.
    SCRIPT_DIR=$(dirname "$(realpath "$0")")
    RESTORE_LOG="$SCRIPT_DIR/restore_log_$(date +%Y%m%d_%H%M%S).txt"

    echo -e "${YELLOW}Logging full output to $RESTORE_LOG${RESET}"

    echo "Preparing device for restore..."
    gaster pwn >> "$RESTORE_LOG" 2>&1
    gaster reset >> "$RESTORE_LOG" 2>&1

    echo -e "${YELLOW}Restore process started. Follow these checkpoints.${RESET}"

    # Run idevicerestore and capture its output
    idevicerestore -d -e "$CURRENT_IPSW_PATH" >> "$RESTORE_LOG" 2>&1 &
    RESTORE_PID=$!
    
    # Start the spinner while the restore process is running
    spinner $RESTORE_PID &

    # Initialize checkpoint flags
    CHECKPOINT_1=false
    CHECKPOINT_2=false
    CHECKPOINT_3=false
    CHECKPOINT_4=false
    CHECKPOINT_5=false
    CHECKPOINT_6=false
    CHECKPOINT_7=false

    while kill -0 $RESTORE_PID 2> /dev/null; do
        sleep 3  # Poll every 3 seconds for status updates

        # Read the last 100 lines of the log to detect certain key progress points
        LAST_LOG_LINES=$(tail -n 100 "$RESTORE_LOG")

        # Check for checkpoints in the log
        if echo "$LAST_LOG_LINES" | grep -q "Now you can boot untrusted images." && [ "$CHECKPOINT_1" = false ]; then
            echo -e "${GREEN}Checkpoint 1: Connected to HomePod${RESET}"
            CHECKPOINT_1=true
        fi
        if echo "$LAST_LOG_LINES" | grep -q "Extracting filesystem from IPSW: myrootfs.dmg" && [ "$CHECKPOINT_2" = false ]; then
            echo -e "${GREEN}Checkpoint 2: Opening IPSW${RESET}"
            CHECKPOINT_2=true
        fi
        if echo "$LAST_LOG_LINES" | grep -q "NOTE: No path for component iBEC in TSS, will fetch from build_identity" && [ "$CHECKPOINT_3" = false ]; then
            echo -e "${GREEN}Checkpoint 3: HomePod entered Recovery Mode${RESET}"
            CHECKPOINT_3=true
        fi
        if echo "$LAST_LOG_LINES" | grep -q "BoardID: 56"         && [ "$CHECKPOINT_4" = false ]; then
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
            
            # Display the QR code for donation to Patreon
            echo -e "${GREEN}Restore successful! If you'd like to support tihmstar for his work on this project, consider donating.${RESET}"
            qrencode -t ANSIUTF8 "https://www.patreon.com/tihmstar"
            
            sleep 45  # Wait for 45 seconds before proceeding

            

            echo -e "${YELLOW}Returning to the main menu...${RESET}"
            sleep 3
            show_menu  # Return to the main menu after the wait
        fi
    done

    wait $RESTORE_PID
    RESTORE_EXIT_CODE=$?
    
    kill $! 2>/dev/null  # Terminate the spinner process
    printf "\n"  # Ensure a newline after the spinner stops

    # Notify user about the result, and don't exit if it's a non-critical error
    if [ "$RESTORE_EXIT_CODE" -ne 0 ] && [ "$CHECKPOINT_7" = false ]; then
        echo -e "${YELLOW}Restore process encountered issues. Please check the full log: $RESTORE_LOG${RESET}"
    else
        echo -e "${GREEN}Restore process completed successfully. Full log saved: $RESTORE_LOG${RESET}"
    fi

    # Return to the main menu
    show_menu
}

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

function create_custom_ipsw() {
    echo "This option is reserved for creating a custom IPSW."
    echo "Returning to the main menu..."
    sleep 5
    show_menu
}

function show_menu() {
    clear
    echo "HomePod Restore Tool"
    echo "Please choose an option:"
    echo "1) Check/Install Dependencies"
    echo "2) Restore HomePod"
    echo "3) Create a Custom IPSW (COMING SOON)"
    echo "4) Update IPSW File Location"
    echo "5) Download Pre-built IPSW"
    echo "6) Update This Script"
    echo "7) Exit"
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
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            show_menu
            ;;
    esac
}

show_menu