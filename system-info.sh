#!/bin/sh
# Production System Information Display Script
# Compatible with POSIX shell - works on minimal containers

# Early exit for non-interactive shells (unless TERM is set for Docker compatibility)
case "$-" in
    *i*) ;;
    *) [ -z "$TERM" ] && return ;;
esac

# Color definitions
readonly YELLOW='\033[38;2;215;153;33m'
readonly ORANGE='\033[38;2;214;93;14m'
readonly BRIGHT_GREEN='\033[38;2;184;187;38m'
readonly WHITE='\033[1;38;2;235;219;178m'
readonly NC='\033[0m'

# Utility function: Check if command exists and works
cmd_exists() {
    "$1" --version >/dev/null 2>&1
}

# Utility function: Check if command exists (simple check)
cmd_available() {
    command -v "$1" >/dev/null 2>&1
}

# Utility function: Safe file read
safe_read() {
    [ -f "$1" ] && cat "$1" 2>/dev/null
}

# Container/Environment Detection
get_container() {
    # Docker detection
    [ -f /.dockerenv ] && echo "Docker" && return
    
    # systemd-nspawn detection
    [ -n "${container}" ] && echo "systemd-nspawn" && return
    
    # LXC detection (multiple methods)
    if [ -f /proc/1/environ ] && grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
        echo "LXC" && return
    fi
    
    if [ -f /proc/1/cgroup ] && grep -q "/lxc/" /proc/1/cgroup 2>/dev/null; then
        echo "LXC" && return
    fi
    
    # systemd-detect-virt if available
    if cmd_available systemd-detect-virt; then
        case "$(systemd-detect-virt 2>/dev/null)" in
            lxc*) echo "LXC" && return ;;
            docker) echo "Docker" && return ;;
            systemd-nspawn) echo "systemd-nspawn" && return ;;
        esac
    fi
    
    echo "Bare Metal"
}

# Hostname Detection
get_hostname() {
    # Try multiple methods in order of preference
    hostname 2>/dev/null && return
    safe_read /proc/sys/kernel/hostname && return
    safe_read /etc/hostname && return
    uname -n 2>/dev/null && return
    echo "${HOSTNAME:-unknown}"
}

# Package Manager Detection
get_pkg_mgr() {
    # Common package managers with their typical distributions
    local pkg_managers="
        apt:ubuntu,debian,mint,kali,pop,elementary
        dnf:fedora,rhel,centos,rocky,alma
        pacman:arch,manjaro,endeavouros,artix
        zypper:opensuse,sles
        apk:alpine,postmarket
        emerge:gentoo,funtoo
        xbps-install:void
        yum:centos,rhel
    "
    
    # Check working package managers first
    for pm_info in $pkg_managers; do
        pm=$(echo "$pm_info" | cut -d: -f1)
        if cmd_exists "$pm"; then
            echo "$pm ✓" && return
        fi
    done
    
    # Fallback: detect by distribution
    local distro_id=""
    if [ -f /etc/os-release ]; then
        distro_id=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    fi
    
    case "$distro_id" in
        ubuntu|debian|mint|kali|pop|elementary) echo "apt ✗" ;;
        fedora|rhel|centos|rocky|alma) echo "dnf ✗" ;;
        arch|manjaro|endeavouros|artix) echo "pacman ✗" ;;
        opensuse*|sles) echo "zypper ✗" ;;
        alpine|postmarket) echo "apk ✗" ;;
        gentoo|funtoo) echo "emerge ✗" ;;
        void) echo "xbps ✗" ;;
        *) echo "unknown" ;;
    esac
}

# Init System Detection
get_init_system() {
    # Check systemd first (most common)
    if cmd_exists systemctl; then
        echo "systemctl ✓" && return
    fi
    
    # Check other init systems
    if [ -f /sbin/openrc ] || cmd_available rc-service; then
        echo "openrc" && return
    fi
    
    if cmd_available service; then
        echo "service" && return
    fi
    
    # Fallback based on PID 1
    case "$(safe_read /proc/1/comm)" in
        systemd) echo "systemctl ✗" ;;
        *init) echo "sysvinit" ;;
        *) echo "unknown" ;;
    esac
}

# Timezone Detection
get_timezone() {
    safe_read /etc/timezone && return
    
    if [ -L /etc/localtime ]; then
        readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' && return
    fi
    
    if cmd_available timedatectl; then
        timedatectl show --property=Timezone --value 2>/dev/null && return
    fi
    
    echo "${TZ:-UTC}"
}

# Local IP Detection
get_local_ip() {
    if cmd_available ip; then
        # Try common interface names and default route
        for method in \
            "ip -4 addr show eth0" \
            "ip -4 addr show ens" \
            "ip route get 1.1.1.1"; do
            
            local ip
            case "$method" in
                *"route get"*)
                    ip=$($method 2>/dev/null | grep -o 'src [0-9.]*' | cut -d' ' -f2)
                    ;;
                *)
                    ip=$($method 2>/dev/null | grep 'inet ' | head -n1 | sed 's/.*inet \([^/]*\).*/\1/')
                    ;;
            esac
            
            if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
                echo "$ip" && return
            fi
        done
        
        # Last resort: any non-localhost IP
        ip=$(ip -4 addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -n1 | sed 's/.*inet \([^/]*\).*/\1/')
        [ -n "$ip" ] && echo "$ip" && return
    fi
    
    # Fallback to hostname if available
    if cmd_available hostname; then
        local ip=$(hostname -i 2>/dev/null | cut -d' ' -f1)
        if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
            echo "$ip" && return
        fi
    fi
    
    echo "unavailable"
}

# Public IP Detection
get_public_ip() {
    local ip=""
    local services="ipinfo.io/ip ipconfig.io api.ipify.org"
    
    # Try curl first
    if cmd_available curl; then
        for service in $services; do
            ip=$(curl -s --max-time 3 "https://$service" 2>/dev/null)
            [ -n "$ip" ] && break
        done
    # Fallback to wget
    elif cmd_available wget; then
        for service in $services; do
            ip=$(wget -qO- --timeout=3 "https://$service" 2>/dev/null)
            [ -n "$ip" ] && break
        done
    else
        echo "curl/wget needed" && return
    fi
    
    # Validate IP format (simple but effective)
    case "$ip" in
        *[!0-9.]*) echo "network unavailable" ;;
        *.*.*.*)
            # Basic IP validation
            if echo "$ip" | grep -q '^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$'; then
                echo "$ip"
            else
                echo "network unavailable"
            fi
            ;;
        *) echo "network unavailable" ;;
    esac
}

# OS Information
get_os_name() {
    if [ -f /etc/os-release ]; then
        grep '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"'
    else
        uname -s 2>/dev/null || echo "Unknown"
    fi
}

get_os_version() {
    if [ -f /etc/os-release ]; then
        grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"'
    else
        uname -r 2>/dev/null || echo "Unknown"
    fi
}

# Main Display Function
display_system_info() {
    printf "\n"
    printf "${WHITE}%s - %s${NC}\n" "$(get_os_name)" "$(get_container)"
    printf "    ${YELLOW}🖥️${NC}  ${ORANGE}Version:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_os_version)"
    printf "    ${YELLOW}🏠${NC}  ${ORANGE}Hostname:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_hostname)"
    printf "    ${YELLOW}👤${NC}  ${ORANGE}User:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(whoami)"
    printf "    ${YELLOW}📦${NC}  ${ORANGE}Package:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_pkg_mgr)"
    printf "    ${YELLOW}⚙️${NC}  ${ORANGE}Services:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_init_system)"
    printf "    ${YELLOW}🌍${NC}  ${ORANGE}Timezone:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_timezone)"
    printf "    ${YELLOW}💡${NC}  ${ORANGE}Local IP:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_local_ip)"
    printf "    ${YELLOW}🌐${NC}  ${ORANGE}Public IP:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_public_ip)"
    printf "\n"
}

# Execute main function
display_system_info
