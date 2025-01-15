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

# Add whitelist to Firejail profile
function add_whitelist {
    FIREJAIL_PROFILE="/etc/firejail/server.profile"
    WHITELIST_ENTRY="whitelist /etc/ssh"

    # Check if the Firejail profile exists
    if [ -f "$FIREJAIL_PROFILE" ]; then
        # Ensure the script has permission to modify the profile
        sudo chmod u+w "$FIREJAIL_PROFILE"
        
        # Add the whitelist entry if it doesn't already exist
        if ! grep -q "$WHITELIST_ENTRY" "$FIREJAIL_PROFILE"; then
            echo "Adding whitelist entry for /etc/ssh to Firejail profile..."
            echo "$WHITELIST_ENTRY" | sudo tee -a "$FIREJAIL_PROFILE"
        else
            echo "Whitelist entry for /etc/ssh already exists in Firejail profile."
        fi

        # Reconfirm the whitelist entry exists
        if grep -q "$WHITELIST_ENTRY" "$FIREJAIL_PROFILE"; then
            echo "Whitelist entry successfully added to Firejail profile."
        else
            echo "Failed to add whitelist entry to Firejail profile. Please check manually."
        fi
    else
        echo "Firejail profile not found at $FIREJAIL_PROFILE. Skipping whitelist addition."
    fi
}

# Comprehensive Service Menu
function service_menu {
    echo "Select a service to run with Firejail:"
    options=(
        "22/SSH"
        "53/DNS"
        "80/HTTP"
        "443/HTTPS"
        "Database (MySQL/PostgreSQL)"
        "FTP (vsftpd/proftpd)"
        "Email (SMTP/POP3/IMAP)"
        "Active Directory (Samba)"
        "DHCP"
        "LAMP Stack (Linux, Apache, MySQL, PHP)"
        "XAMPP Stack (Cross-platform Apache, MySQL, PHP, Perl)"
        "Node.js Web Server"
        "Python Flask/Django Web App"
        "Ruby on Rails Web App"
        "Ecommerce Platform (Magento/OpenCart)"
        "Exit"
    )

    select opt in "${options[@]}"; do
        case $opt in
            "22/SSH")
                echo "Running SSH in Firejail with default profile..."
                echo "Ensure the Firejail profile (/etc/firejail/server.profile) grants access to /etc/ssh and any other necessary files."
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
            "XAMPP Stack (Cross-platform Apache, MySQL, PHP, Perl)")
                echo "Running XAMPP Stack in Firejail..."
                sudo firejail /opt/lampp/lampp start
                ;;
            "Node.js Web Server")
                echo "Running Node.js Web Server in Firejail..."
                sudo firejail node /path/to/your/app.js
                ;;
            "Python Flask/Django Web App")
                echo "Running Python Flask/Django App in Firejail..."
                sudo firejail python3 /path/to/your/app.py
                ;;
            "Ruby on Rails Web App")
                echo "Running Ruby on Rails App in Firejail..."
                sudo firejail rails server -b 0.0.0.0
                ;;
            "Ecommerce Platform (Magento/OpenCart)")
                echo "Running Ecommerce Platform in Firejail..."
                sudo firejail /usr/sbin/apache2 -D FOREGROUND &
                sudo firejail /usr/sbin/mysqld_safe &
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
    echo "Configuring Firejail profile..."
    add_whitelist
    echo "Configuration complete."
    service_menu
}

main
