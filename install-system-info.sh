#!/bin/sh

REPO_URL="https://raw.githubusercontent.com/Bramba7/sysinfo/main/system-info.sh"
TEMP_PATH="/tmp/system-info.sh"
BIN_PATH="/usr/local/bin/sysinfo"
PROFILE_PATH="/etc/profile.d/01-system-info.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# Utility functions
show_success() {
    printf "$GREEN✓$NC $1\n"
}

show_error() {
    printf "$RED✗$NC $1\n"
}

# Check privileges
check_privileges() {
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
    elif command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        show_error "Root access required"
        exit 1
    fi
}

# Download script with curl/wget fallback
download_script() {
    local output_path="$1"
    local success=0
    
    # Clean up any existing file first
    rm -f "$output_path" 2>/dev/null
    
    # Try curl first
    if command -v curl >/dev/null 2>&1; then
        if curl -sSL "$REPO_URL" -o "$output_path" 2>/dev/null; then
            # Verify file was created and has content
            if [ -f "$output_path" ] && [ -s "$output_path" ]; then
                success=1
            else
                rm -f "$output_path" 2>/dev/null
            fi
        fi
    fi
    
    # Fallback to wget if curl failed
    if [ "$success" -eq 0 ] && command -v wget >/dev/null 2>&1; then
        if wget -qO "$output_path" "$REPO_URL" 2>/dev/null; then
            # Verify file was created and has content
            if [ -f "$output_path" ] && [ -s "$output_path" ]; then
                success=1
            else
                rm -f "$output_path" 2>/dev/null
            fi
        fi
    fi
    
    # Check if download was successful
    if [ "$success" -eq 1 ]; then
        return 0
    else
        show_error "Download failed - check internet connection"
        return 1
    fi
}

# Main menu
show_menu() {
    printf "\n"
    printf "$WHITE%s$NC\n" "System Info Script Installer"
    printf "$GRAY%s$NC\n" "────────────────────────────────────────"
    printf "\n"
    printf "$WHITE[1]$NC Quick Test          $GRAY- Run once$NC\n"
    printf "$WHITE[2]$NC Command Tool        $GRAY- Install as 'sysinfo'$NC\n"
    printf "$WHITE[3]$NC Auto-start          $GRAY- Show on login$NC\n"
    printf "\n"
    printf "$WHITE[q]$NC Quit\n"
    printf "\n"
    printf "$YELLOW❯$NC "
}

# Installation functions
install_quick_test() {
    printf "\n"
    if download_script "$TEMP_PATH"; then
        if [ -f "$TEMP_PATH" ] && [ -s "$TEMP_PATH" ]; then
            chmod +x "$TEMP_PATH" 2>/dev/null
            printf "\n"
            if ! "$TEMP_PATH" 2>/dev/null; then
                sh "$TEMP_PATH" 2>/dev/null || show_error "Script execution failed"
            fi
            rm -f "$TEMP_PATH" 2>/dev/null
        else
            show_error "Download failed"
        fi
    else
        show_error "Download failed"
    fi
}

install_command_tool() {
    printf "\n"
    check_privileges
    
    if download_script "/tmp/sysinfo-temp"; then
        if [ -f "/tmp/sysinfo-temp" ] && [ -s "/tmp/sysinfo-temp" ]; then
            if ${SUDO} mv "/tmp/sysinfo-temp" "$BIN_PATH" 2>/dev/null && ${SUDO} chmod +x "$BIN_PATH" 2>/dev/null; then
                show_success "Installed as 'sysinfo' command"
                printf "\n"
                if ! "$BIN_PATH" 2>/dev/null; then
                    sh "$BIN_PATH" 2>/dev/null || show_error "Script execution failed"
                fi
            else
                show_error "Installation failed"
                rm -f "/tmp/sysinfo-temp" 2>/dev/null
            fi
        else
            show_error "Download failed"
        fi
    else
        show_error "Download failed"
    fi
}

install_auto_start() {
    printf "\n"
    check_privileges
    
    if download_script "/tmp/profile-temp"; then
        if [ -f "/tmp/profile-temp" ] && [ -s "/tmp/profile-temp" ]; then
            if ${SUDO} mv "/tmp/profile-temp" "$PROFILE_PATH" 2>/dev/null && ${SUDO} chmod +x "$PROFILE_PATH" 2>/dev/null; then
                show_success "Installed to $PROFILE_PATH"
                printf "\n"
                if ! "$PROFILE_PATH" 2>/dev/null; then
                    sh "$PROFILE_PATH" 2>/dev/null || show_error "Script execution failed"
                fi
            else
                show_error "Installation failed"
                rm -f "/tmp/profile-temp" 2>/dev/null
            fi
        else
            show_error "Download failed"
        fi
    else
        show_error "Download failed"
    fi
}

# Input validation
get_choice() {
    while true; do
        show_menu
        read choice < /dev/tty
        
        case "$choice" in
            1|"")
                install_quick_test
                break
                ;;
            2)
                install_command_tool
                break
                ;;
            3)
                install_auto_start
                break
                ;;
            q|Q)
                printf "\n"
                exit 0
                ;;
            *)
                printf "\n"
                show_error "Invalid choice"
                printf "Press Enter to continue..."
                read dummy < /dev/tty
                ;;
        esac
    done
}

# Cleanup on exit
cleanup() {
    rm -f "$TEMP_PATH" "/tmp/sysinfo-temp" "/tmp/profile-temp" 2>/dev/null
}

trap cleanup EXIT

# Main execution
get_choice
printf "\n"
