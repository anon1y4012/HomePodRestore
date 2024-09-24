#!/bin/bash

# Color variables
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET='\033[0m'  # Reset to default color

# Variables
DOWNLOADS_DIR="$HOME/Downloads"
IPSW_FILE_PATH=""

# Pre-defined IPSW path stored within the script
CURRENT_IPSW_PATH=""

BREW_DEPENDENCIES=("libimobiledevice-glue" "libimobiledevice" "libirecovery" "idevicerestore" "gaster" "ldid-procursus" "tsschecker" "img4tool" "ra1nsn0w")

IPSW_DOWNLOAD_URL="https://nicsfix.com/ipsw/17.6.ipsw"

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

            # Get the current user's home directory
            USER_HOME=$(eval echo ~$USER)

            # Append the necessary configuration to the user's profile
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
    install_dependencies  # Ensure dependencies are installed even if Homebrew is already present
    echo "Returning to the main menu..."
    sleep 3
    show_menu  # Return to the main menu
}


function spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"  # Backspace to clear the spinner characters
    done
    printf "\b\b\b\b\b\b"  # Clean up any leftover spinner characters
}


function install_dependencies() {
    echo -e "${YELLOW}Press CTRL+C at any time to return to the main menu.${RESET}"
    echo "Tapping d235j/ios-restore-tools..."
    brew tap d235j/ios-restore-tools

    for dep in "${BREW_DEPENDENCIES[@]}"; do
        if ! brew list $dep &> /dev/null; then
            echo "Installing $dep..."
            brew install --HEAD "$dep"
        else
            echo "$dep is already installed."
        fi
    done
}


# Function to prompt for an IPSW file path and store it within the script
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
    
    # Escape slashes for use in sed
    escaped_new_path=$(echo "$new_path" | sed 's/\//\\\//g')

    # Use sed to replace the CURRENT_IPSW_PATH with the new path
    sed -i '' "s|^CURRENT_IPSW_PATH=.*|CURRENT_IPSW_PATH=\"$escaped_new_path\"|" "$0"
    
    # Update the global variable for the current session
    CURRENT_IPSW_PATH="$new_path"
    
    echo -e "${GREEN}IPSW file path successfully updated to: $new_path${RESET}"
}

# Function to download the IPSW
function download_ipsw() {
    SCRIPT_DIR=$(dirname "$(realpath "$0")")
    IPSW_DEST_PATH="$SCRIPT_DIR/17.6.ipsw"
    
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
    sleep 3
    show_menu
}

# Update the IPSW path only
function update_ipsw_path() {
    echo "Updating the IPSW file location..."
    prompt_for_ipsw_path
    echo "IPSW path updated successfully."
    echo -e "${YELLOW}Returning to the main menu...${RESET}"
    sleep 3
    show_menu  # Return to the main menu after updating the path
}

# Function to retrieve the stored IPSW path or prompt for it if not found
function get_ipsw_path() {
    # If no path is set in CURRENT_IPSW_PATH, prompt the user
    if [[ -z "$CURRENT_IPSW_PATH" || ! -f "$CURRENT_IPSW_PATH" ]]; then
        echo "No valid IPSW file path found. Please provide the IPSW file path."
        prompt_for_ipsw_path
    else
        echo -e "${GREEN}Using stored IPSW file path: $CURRENT_IPSW_PATH${RESET}"
    fi
}


function check_device_in_dfu() {
    echo -e "${YELLOW}Checking if a HomePod is connected in DFU mode...${RESET}"
    
    # Check for a device in DFU mode using ideviceinfo or irecovery
    device_info=$(irecovery -q 2>&1)
    
    if echo "$device_info" | grep -q "ERROR: No device found"; then
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
            sleep 45  # Wait for 45 seconds before proceeding
            echo -e "${YELLOW}Returning to the main menu...${RESET}"
            sleep 3
            show_menu  # Return to the main menu after the wait
        fi

        # Detect and handle non-critical failure messages without stopping
        if echo "$LAST_LOG_LINES" | grep -q "ampctl failure" || echo "$LAST_LOG_LINES" | grep -q "RamrodErrorDomain"; then
            echo -e "${YELLOW}Non-critical error detected (ampctl or RamrodErrorDomain). THIS IS NORMAL. Continuing...${RESET}"
        fi

        # Detect if the IPSW is no longer signed by Apple
        if echo "$LAST_LOG_LINES" | grep -q "This device isn't eligible for the requested build"; then
           echo -e "${RED}This IPSW is no longer signed by Apple, you will need a newer IPSW. Returning to main menu...${RESET}"
           sleep 7  
           show_menu  # Return to the main menu
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
    
    # Define the URL where the latest script is hosted (raw content)
    SCRIPT_URL="https://raw.githubusercontent.com/anon1y4012/HomePodRestore/main/restorer.sh"

    # Temporary location to download the new script
    TEMP_SCRIPT="/tmp/latest_homepod_restore_script.sh"

    # Download the latest version of the script
    curl -L -o "$TEMP_SCRIPT" "$SCRIPT_URL"

    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Failed to download the latest script. Please check your connection or the URL.${RESET}"
        sleep 3
        show_menu
        return
    fi

    # Overwrite the current script with the new one
    chmod +x "$TEMP_SCRIPT"  # Ensure the downloaded script is executable

    # Replace the current script with the new one
    mv "$TEMP_SCRIPT" "$0"

    # Restart the script
    echo -e "${GREEN}Script updated successfully. Restarting...${RESET}"
    sleep 5
    exec "$0"  # Restart the script by executing it again
}

function create_custom_ipsw() {
    echo "This option is reserved for creating a custom IPSW."
    echo "Returning to the main menu..."
    show_menu  # Return to the main menu
}

# UI Function for User Input
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
            echo "Option 1 selected: Checking and installing dependencies..."
            check_homebrew
            install_dependencies
            ;;
        2)
            echo "Option 2 selected: Restoring HomePod..."
            restore_homepod
            ;;
        3)
            echo "Option 3 selected: Creating a custom IPSW..."
            create_custom_ipsw
            ;;
        4)
            echo "Option 4 selected: Updating IPSW File Location..."
            prompt_for_ipsw_path  # Fixed to correctly prompt the user for a path
            ;;
        5)
            echo "Option 5 selected: Downloading Pre-built IPSW..."
            download_ipsw
            ;;
        6)
            echo "Option 6 selected: Updating this script with the latest version..."
            update_script
            ;;
        7)
            echo "Exiting the script."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            show_menu
            ;;
    esac
}

# Main script
show_menu