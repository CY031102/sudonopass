#!/bin/bash

show_welcome() {
    clear
    echo "=================================================="
    echo -e "\e[1m"  # Bold text start
    echo "  ███████╗██╗   ██╗ ██████╗   ██████╗         ██╗ "
    echo "  ██╔════╝██║   ██║ ██╔══██╗ ██╔═══██╗        ██║ "
    echo "  ███████╗██║   ██║ ██║  ██║ ██║   ██║ █████╗ ██║ "
    echo "  ╚════██║██║   ██║ ██║  ██║ ██║   ██║ ╚════╝ ██║ "
    echo "  ███████║╚██████╔╝ ██████╔╝ ╚██████╔╝        ██║ "
    echo "  ╚══════╝ ╚═════╝  ╚═════╝   ╚═════╝         ╚═╝ "
    echo "                                                  "
    echo -e "\e[0m"  # Bold text end
    echo "=================================================="
    echo ""
    echo "This script configures passwordless sudo -i."
    echo "After completion, the selected user will be able to run"
    echo "'sudo -i' without being prompted for a password."
    echo "                                                  "
    echo "=================================================="
    echo ""
    echo "Press any key to start..."
    echo "Ctrl+C to Exit"
    read -n 1 -s
}

# Function to display progress bar with a 0.4s delay

progress_bar() {
    local progress="$1"
    local total=100
    local bar_width=20
    local num_chars=$(( (progress * bar_width) / total ))

    # Ensure the progress bar is fully filled at 100%
    if (( progress == 100 )); then
        num_chars=$bar_width
    fi

    # Move cursor to the bottom left
    echo -ne "\033[s"  # Save cursor position
    echo -ne "\033[999;0H"  # Move to bottom-left corner
    echo -ne ">>> ${progress}% \e[32m["  # Start green color
    printf '='%.0s $(seq 1 $num_chars)  # Print filled portion in green
    printf ' '%.0s $(seq $((num_chars + 1)) $bar_width)  # Print empty space
    echo -ne "]\e[0m"  # Reset color
    echo -ne "\033[u"  # Restore cursor position

    sleep 0.4
}


# Step 1: Get all human users (UID >= 1000) excluding "nobody"

get_users() {
    echo ""  
    progress_bar 10
    echo "Finding users..."
    ALL_USERS=$(awk -F: '$3 >= 1000 {print $1}' /etc/passwd | grep -v "nobody")

    if [ -z "$ALL_USERS" ]; then
        echo -e "\e[1;41m ERROR: No valid human users found! Exiting. \e[0m"
        exit 1
    fi

    USER_ARRAY=()
    for user in $ALL_USERS; do
        USER_ARRAY+=("$user")
    done
    progress_bar 20
}

# Function to select a user

select_user() {
    progress_bar 30
    echo ""
    echo -e "\e[1;36mChoose which user to configure for passwordless sudo -i:\e[0m"  # Bold Cyan
    local index=1
    for user in "${USER_ARRAY[@]}"; do
        echo "$index. $user"
        index=$((index + 1))
    done

    local attempts=0
    while true; do
        echo -ne "\e[1;37mEnter the number corresponding to the user (default: 1): \e[0m"
        read USER_CHOICE

        # If user presses ENTER without input, default to first user
        if [[ -z "$USER_CHOICE" ]]; then
            USER_CHOICE=1
        fi

        # Validate input
        if [[ "$USER_CHOICE" =~ ^[0-9]+$ ]]; then
            if (( USER_CHOICE >= 1 && USER_CHOICE <= ${#USER_ARRAY[@]} )); then
                SELECTED_USER="${USER_ARRAY[$((USER_CHOICE-1))]}"
                progress_bar 40
                return
            fi
        fi

        # Increment attempts
        attempts=$((attempts + 1))
        echo -e "\e[1;33mInvalid choice. Please try again. ($attempts/3)\e[0m"

        # If failed 3 times, return to welcome page
        if [ "$attempts" -ge 3 ]; then
            echo -e "\e[1;41mToo many invalid attempts. Restarting...\e[0m"
            echo "Returning to menu in 3 seconds..."
            sleep 3
            main
        fi
    done
}


# Function to check if user is already configured

check_existing_sudoers() {
    progress_bar 50
    echo ""  
    echo "Checking system sudoers file..."
    if sudo grep -q "^$SELECTED_USER ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
        echo -e "User \e[1;35m$SELECTED_USER\e[0m is \e[1;37m\e[4malready configured\e[0m in /etc/sudoers."
        echo -e "\e[32m\033[1mNo changes made.\033[0m"  # Green + Bold for positive message
        exit 0
    fi

    echo "Checking /etc/sudoers.d/ directory..."
    for FILE in /etc/sudoers.d/*; do
        if sudo grep -q "^$SELECTED_USER ALL=(ALL) NOPASSWD: ALL" "$FILE"; then
            echo -e "User \e[1;35m$SELECTED_USER\e[0m is \e[1;37m\e[4malready configured\e[0m in $FILE."
            echo -e "\e[32m\033[1mNo changes made.\033[0m"
            exit 0
        fi
    done
}


# Function to configure passwordless sudo

configure_sudo() {
    progress_bar 75
    echo ""
    SUDOERS_FILE="/etc/sudoers.d/admin"

    echo "Creating or updating sudoers file..."
    echo "$SELECTED_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee -a "$SUDOERS_FILE" > /dev/null

    echo "Setting correct file permissions..."
    sudo chmod 440 "$SUDOERS_FILE"

    progress_bar 100
    echo ""  
    echo -e "\e[1mPasswordless sudo configured for \e[1;35m$SELECTED_USER\e[0m\e[1m.\e[0m"
    echo -e "\e[1;32mProcess complete!\e[0m \e[1;37mEnjoy your sudo powers!!!\e[0m"
    echo ""
}


# Main function to restart the script if needed
main() {
    show_welcome
    get_users
    select_user
    check_existing_sudoers
    configure_sudo
}

# Run the script
main
