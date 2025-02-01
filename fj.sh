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

# Install Firejail using the distribution package manager
function install_firejail {
    if command -v firejail &> /dev/null; then
        echo "Firejail is already installed. Skipping installation."
        return
    fi

    if [ "$PM" == "apt-get" ]; then
        sudo add-apt-repository -y ppa:deki/firejail
        sudo apt-get update
        sudo apt-get install -y firejail firejail-profiles build-essential git libapparmor-dev pkg-config gawk
    elif [ "$PM" == "dnf" ]; then
        sudo dnf install -y firejail git gcc make libselinux-devel
    elif [ "$PM" == "zypper" ]; then
        sudo zypper install -y firejail git gcc make
    elif [ "$PM" == "yum" ]; then
        sudo yum install -y epel-release
        sudo yum install -y firejail git gcc make libselinux-devel
    else
        echo "Failed to install Firejail. Unsupported package manager."
        exit 1
    fi
}

# Build and install Firejail from source for the latest features
function build_firejail {
    echo "Building Firejail from source..."
    git clone https://github.com/netblue30/firejail.git
    cd firejail
    ./configure --enable-apparmor --enable-selinux
    make
    sudo make install-strip
    cd ..
    rm -rf firejail
}

# Fix Firejail profile configuration
function configure_firejail_profiles {
    echo "Configuring Firejail profiles..."

    FIREJAIL_PROFILES=("/etc/firejail/server.profile" "/etc/firejail/ssh.profile")
    WHITELIST_ENTRIES=("whitelist /etc/ssh" "whitelist /etc/ssh/sshd_config")

    for PROFILE in "${FIREJAIL_PROFILES[@]}"; do
        if [ -f "$PROFILE" ]; then
            sudo chmod u+w "$PROFILE"
            for ENTRY in "${WHITELIST_ENTRIES[@]}"; do
                if ! grep -q "$ENTRY" "$PROFILE"; then
                    echo "$ENTRY" | sudo tee -a "$PROFILE" > /dev/null
                fi
            done
        else
            sudo touch "$PROFILE"
            echo "include /etc/firejail/disable-common.inc" | sudo tee -a "$PROFILE" > /dev/null
            echo "include /etc/firejail/disable-programs.inc" | sudo tee -a "$PROFILE" > /dev/null
            for ENTRY in "${WHITELIST_ENTRIES[@]}"; do
                echo "$ENTRY" | sudo tee -a "$PROFILE" > /dev/null
            done
        fi
    done

    sudo chmod 644 /etc/ssh/sshd_config
    sudo chmod 755 /etc/ssh
}

# Comprehensive Service Menu
function service_menu {
    echo "Select a service to run with Firejail:"
    options=("22/SSH" "Exit")

    select opt in "${options[@]}"; do
        case $opt in
            "22/SSH")
                echo "Running SSH in Firejail..."
                sudo firejail --debug --profile=/etc/firejail/ssh.profile /usr/sbin/sshd -D
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

# Ensure /etc/ld.so.preload exists to prevent errors
function ensure_ld_preload {
    if [ ! -f /etc/ld.so.preload ]; then
        sudo touch /etc/ld.so.preload
        echo "/etc/ld.so.preload created to avoid Firejail errors."
    fi
}

# Main Function
function main {
    detect_distro
    echo "Installing Firejail..."
    install_firejail
    echo "Building Firejail from source..."
    build_firejail
    echo "Configuring Firejail profiles..."
    configure_firejail_profiles
    echo "Ensuring /etc/ld.so.preload exists..."
    ensure_ld_preload
    echo "Configuration complete."
    service_menu
}

main
