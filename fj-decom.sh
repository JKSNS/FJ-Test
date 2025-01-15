#!/bin/bash

# Detect Linux distribution
function detect_distro {
    if command -v apt-get &> /dev/null; then
        echo "Debian-based OS detected (apt-get available)."
        PM="apt-get"
    elif command -v dnf &> /dev/null; then
        echo "Fedora-based OS detected (dnf available)."
        PM="dnf"
    elif command -v zypper &> /dev/null; then
        echo "OpenSUSE-based OS detected (zypper available)."
        PM="zypper"
    elif command -v yum &> /dev/null; then
        echo "RHEL-based OS detected (yum available)."
        PM="yum"
    else
        echo "Unsupported OS. Exiting."
        exit 1
    fi
}

# Install Firejail
function install_firejail {
    if [ "$PM" == "apt-get" ]; then
        sudo apt-get update
        sudo apt-get install -y firejail
    elif [ "$PM" == "dnf" ]; then
        sudo dnf install -y firejail
    elif [ "$PM" == "zypper" ]; then
        sudo zypper install -y firejail
    elif [ "$PM" == "yum" ]; then
        sudo yum install -y epel-release
        sudo yum install -y firejail
    else
        echo "Failed to install Firejail. Unsupported package manager."
        exit 1
    fi
}

# Menu for critical services
function service_menu {
    echo "Select a service to run with Firejail:"
    options=(
        "22/SSH"
        "53/DNS"
        "80/HTTP"
        "443/HTTPS"
        "Exit"
    )
    select opt in "${options[@]}"; do
        case $opt in
            "22/SSH")
                echo "Running SSH in Firejail..."
                sudo firejail /usr/sbin/sshd -D
                ;;
            "53/DNS")
                echo "Running DNS in Firejail..."
                sudo firejail /usr/sbin/named -f
                ;;
            "80/HTTP")
                echo "Running HTTP in Firejail..."
                sudo firejail /usr/sbin/apache2 -D FOREGROUND
                ;;
            "443/HTTPS")
                echo "Running HTTPS in Firejail..."
                sudo firejail /usr/sbin/nginx -g "daemon off;"
                ;;
            "Exit")
                echo "Exiting."
                break
                ;;
            *)
                echo "Invalid option. Try again."
                ;;
        esac
    done
}

# Main function
function main {
    detect_distro
    echo "Installing Firejail..."
    install_firejail
    echo "Firejail installation complete."
    service_menu
}

main
