#!/bin/bash

#Create directory for logging
sudo mkdir /var/log/user_management.log
sudo mkdir /var/secure/user_passwords.txt

# Define the log file and password storage file
ACTION_LOG="/var/log/user_management.log"
PASSWORD_LOG="/var/secure/user_passwords.txt"

# Check if a file is provided as an argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <filename>" | tee -a "$ACTION_LOG"
    exit 1
fi

FILENAME=$1

# Check if the file exists
if [ ! -f "$FILENAME" ]; then
    echo "File $FILENAME does not exist." | tee -a "$ACTION_LOG"
    exit 1
fi

# Ensure the password file exists and is secured
sudo touch "$PASSWORD_LOG"
sudo chmod 600 "$PASSWORD_LOG"

# Function to generate a random password
generate_password() {
    openssl rand -base64 12
}

# Read the file line by line
while IFS=';' read -r username groups; do
    # Check if the user already exists
    if id -u "$username" >/dev/null 2>&1; then
        echo "User $username already exists." | tee -a "$ACTION_LOG"
    else
        # Create the user with a home directory and generate a random password
        password=$(generate_password)
        encrypted_password=$(openssl passwd -1 "$password")
        
        sudo useradd -m -p "$encrypted_password" "$username"
        if [ $? -eq 0 ]; then
            echo "User $username created with home directory." | tee -a "$ACTION_LOG"
            echo "$username:$password" | sudo tee -a "$PASSWORD_LOG" > /dev/null
        else
            echo "Failed to create user $username." | tee -a "$ACTION_LOG"
            continue
        fi
    fi

    # Assign the user to the groups
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        # Check if the group exists, create it if it does not
        if ! getent group "$group" >/dev/null 2>&1; then
            sudo groupadd "$group"
            if [ $? -eq 0 ]; then
                echo "Group $group created." | tee -a "$ACTION_LOG"
            else
                echo "Failed to create group $group." | tee -a "$ACTION_LOG"
                continue
            fi
        fi

        # Add the user to the group
        sudo usermod -aG "$group" "$username"
        if [ $? -eq 0 ]; then
            echo "User $username added to group $group." | tee -a "$ACTION_LOG"
        else
            echo "Failed to add user $username to group $group." | tee -a "$ACTION_LOG"
        fi
    done

    # Set appropriate permissions for the home directory
    sudo chmod 700 "/home/$username"
    sudo chown "$username:$username" "/home/$username"
    if [ $? -eq 0 ]; then
        echo "Set permissions for home directory of $username." | tee -a "$ACTION_LOG"
    else
        echo "Failed to set permissions for home directory of $username." | tee -a "$ACTION_LOG"
    fi

done < "$FILENAME"

echo "User and group creation process completed." | tee -a "$ACTION_LOG"
