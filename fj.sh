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
        echo "Adding Firejail PPA for Ubuntu..."
        sudo add-apt-repository -y ppa:deki/firejail
        sudo apt-get update
        echo "Installing Firejail and recommended profiles..."
        sudo apt-get install -y firejail firejail-profiles build-essential git libapparmor-dev pkg-config gawk
    elif [ "$PM" == "dnf" ]; then
        echo "Installing Firejail and dependencies on Fedora..."
        sudo dnf install -y firejail git gcc make libselinux-devel
    elif [ "$PM" == "zypper" ]; then
        echo "Installing Firejail on OpenSUSE..."
        sudo zypper install -y firejail git gcc make
    elif [ "$PM" == "yum" ]; then
        echo "Enabling EPEL repository and installing Firejail on RHEL/CentOS..."
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
    echo "Firejail successfully built and installed from source."
}

# Clone and copy profiles from GitHub repository
function fetch_firejail_profiles {
    echo "Cloning Firejail profiles repository..."
    git clone https://github.com/chiraag-nataraj/firejail-profiles.git /tmp/firejail-profiles
    echo "Copying profiles to /etc/firejail..."
    sudo cp /tmp/firejail-profiles/*.profile /etc/firejail/
    sudo cp /tmp/firejail-profiles/common.inc /etc/firejail/
    sudo chmod 644 /etc/firejail/*.profile
    sudo chmod 644 /etc/firejail/common.inc
    if [ ! -f /etc/firejail/common.inc ]; then
        echo "Error: common.inc file is missing. Aborting."
        exit 1
    fi
    rm -rf /tmp/firejail-profiles
    echo "Firejail profiles have been successfully added."
}

# Add whitelist entries to Firejail profiles
function add_whitelist {
    FIREJAIL_PROFILES=("/etc/firejail/server.profile" "/etc/firejail/ssh.profile")
    WHITELIST_ENTRIES=("whitelist /etc/ssh" "whitelist /etc/ssh/sshd_config")

    for PROFILE in "${FIREJAIL_PROFILES[@]}"; do
        if [ -f "$PROFILE" ]; then
            sudo chmod u+w "$PROFILE"

            for ENTRY in "${WHITELIST_ENTRIES[@]}"; do
                if ! grep -q "$ENTRY" "$PROFILE"; then
                    echo "Adding $ENTRY to $PROFILE..."
                    echo "$ENTRY" | sudo tee -a "$PROFILE" > /dev/null
                else
                    echo "$ENTRY already exists in $PROFILE."
                fi
            done
        else
            echo "Firejail profile not found at $PROFILE. Creating it."
            echo -e "include /etc/firejail/common.inc\ninclude /etc/firejail/disable-common.inc\ninclude /etc/firejail/disable-programs.inc" | sudo tee "$PROFILE" > /dev/null
            sudo chmod 644 "$PROFILE"
        fi
    done

    echo "Setting correct permissions for /etc/ssh/sshd_config..."
    sudo chmod 644 /etc/ssh/sshd_config
    sudo chmod 755 /etc/ssh
}

# Comprehensive Service Menu
function service_menu {
    echo "Select a service to run with Firejail:"
    options=(
        "22/SSH"
        "53/DNS"
        "80/HTTP"
        "443/HTTPS"
        "135/NetBIOS"
        "139/SMB"
        "445/SMB"
        "3389/RDP"
        "Database (MySQL/PostgreSQL)"
        "FTP (vsftpd/proftpd)"
        "Email (SMTP/POP3/IMAP)"
        "Active Directory (Samba)"
        "DHCP"
        "LAMP Stack (Linux, Apache, MySQL, PHP)"
        "Exit"
    )

    select opt in "${options[@]}"; do
        case $opt in
            "22/SSH")
                echo "Running SSH in Firejail with default profile..."
                sudo firejail --profile=/etc/firejail/ssh.profile /usr/sbin/sshd -D
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
            "135/NetBIOS")
                echo "Running NetBIOS in Firejail..."
                sudo firejail /usr/sbin/nmbd -F
                ;;
            "139/SMB")
                echo "Running SMB in Firejail..."
                sudo firejail /usr/sbin/smbd -F
                ;;
            "445/SMB")
                echo "Running SMB on port 445 in Firejail..."
                sudo firejail /usr/sbin/smbd -F
                ;;
            "3389/RDP")
                echo "Running RDP in Firejail..."
                sudo firejail /usr/sbin/xrdp -nodaemon
                ;;
            "Database (MySQL/PostgreSQL)")
                echo "Select Database:"
                select db in "MySQL" "PostgreSQL"; do
                    case $db in
                        "MySQL")
                            echo "Running MySQL in Firejail..."
                            sudo firejail /usr/sbin/mysqld_safe
                            break
                            ;;
                        "PostgreSQL")
                            echo "Running PostgreSQL in Firejail..."
                            sudo firejail /usr/pgsql/bin/postgres -D /var/lib/pgsql/data
                            break
                            ;;
                        *)
                            echo "Invalid option. Try again."
                            ;;
                    esac
                done
                ;;
            "FTP (vsftpd/proftpd)")
                echo "Select FTP Server:"
                select ftp in "vsftpd" "proftpd"; do
                    case $ftp in
                        "vsftpd")
                            echo "Running vsftpd in Firejail..."
                            sudo firejail /usr/sbin/vsftpd
                            break
                            ;;
                        "proftpd")
                            echo "Running proftpd in Firejail..."
                            sudo firejail /usr/sbin/proftpd
                            break
                            ;;
                        *)
                            echo "Invalid option. Try again."
                            ;;
                    esac
                done
                ;;
            "Email (SMTP/POP3/IMAP)")
                echo "Running Email Server in Firejail..."
                sudo firejail /usr/sbin/postfix start
                sudo firejail /usr/sbin/dovecot
                ;;
            "Active Directory (Samba)")
                echo "Running Samba for AD in Firejail..."
                sudo firejail /usr/sbin/smbd -F
                ;;
            "DHCP")
                echo "Running DHCP Server in Firejail..."
                sudo firejail /usr/sbin/dhcpd -f
                ;;
            "LAMP Stack (Linux, Apache, MySQL, PHP)")
                echo "Running LAMP Stack in Firejail..."
                sudo firejail /usr/sbin/apache2 -D FOREGROUND &
                sudo firejail /usr/sbin/mysqld_safe &
                echo "LAMP Stack running."
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

function main {
    detect_distro
    echo "Installing Firejail..."
    install_firejail
    echo "Firejail installation complete."
    echo "Building Firejail from source for latest features..."
    build_firejail
    echo "Fetching additional Firejail profiles..."
    fetch_firejail_profiles
    echo "Configuring Firejail profiles..."
    add_whitelist
    echo "Configuration complete."
    service_menu
}

main
