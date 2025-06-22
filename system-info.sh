#!/bin/sh
# Production System Information Display Script
# Compatible with POSIX shell - works on minimal containers

# Early exit for non-interactive shells (unless TERM is set for Docker compatibility)
case "$-" in#!/bin/bash
# /etc/profile.d/01-system-info.sh

# For zsh users - add to ~/.zshrc:
#echo 'source /etc/profile.d/01-system-info.sh' >> ~/.zshrc


# Show for interactive shells or if TERM is set (Docker compatibility)
[[ $- != *i* ]] && [[ -z "$TERM" ]] && return

# Colors (only used ones)
YELLOW='\033[38;2;215;153;33m'
ORANGE='\033[38;2;214;93;14m'
BRIGHT_GREEN='\033[38;2;184;187;38m'
RED='\033[38;2;204;36;29m'
WHITE='\033[1;38;2;235;219;178m'
NC='\033[0m'

# Container/environment detection
get_container() {
    [ -f /.dockerenv ] && echo "Docker" && return
    [ -n "${container}" ] && echo "systemd-nspawn" && return
    grep -q "lxc" /proc/1/cgroup 2>/dev/null && echo "LXC" && return
    [ -f /run/systemd/container ] && cat /run/systemd/container 2>/dev/null && return
    echo "Bare Metal"
}

# Init system detection
get_init_system() {
    # Check if systemctl exists and works
    if command -v systemctl &>/dev/null && systemctl --version &>/dev/null 2>&1; then
        echo "systemctl ✓"
        return
    fi
    
    # Check for other init systems
    if [ -f /sbin/openrc ] || command -v rc-service &>/dev/null; then
        echo "openrc"
        return
    fi
    
    if command -v service &>/dev/null; then
        echo "service"
        return
    fi
    
    if [ -f /etc/init.d ] && [ -d /etc/init.d ]; then
        echo "sysvinit"
        return
    fi
    
    # Fallback based on PID 1
    if [ -f /proc/1/comm ]; then
        case "$(cat /proc/1/comm 2>/dev/null)" in
            systemd) echo "systemctl ✗" ;;
            init) echo "sysvinit" ;;
            openrc*) echo "openrc" ;;
            *) echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}
get_pkg_mgr() {
    # Test both existence AND functionality in one go
    command -v apt &>/dev/null && apt --version &>/dev/null && echo "apt ✓" && return
    command -v dnf &>/dev/null && dnf --version &>/dev/null && echo "dnf ✓" && return
    command -v yum &>/dev/null && yum --version &>/dev/null && echo "yum ✓" && return
    command -v zypper &>/dev/null && zypper --version &>/dev/null && echo "zypper ✓" && return
    command -v pacman &>/dev/null && pacman --version &>/dev/null && echo "pacman ✓" && return
    command -v apk &>/dev/null && apk --version &>/dev/null && echo "apk ✓" && return
    command -v emerge &>/dev/null && emerge --version &>/dev/null && echo "emerge ✓" && return
    command -v xbps-install &>/dev/null && xbps-install --version &>/dev/null && echo "xbps ✓" && return
    command -v nix-env &>/dev/null && nix-env --version &>/dev/null && echo "nix ✓" && return
    command -v eopkg &>/dev/null && eopkg --version &>/dev/null && echo "eopkg ✓" && return
    command -v swupd &>/dev/null && swupd --version &>/dev/null && echo "swupd ✓" && return
    command -v installpkg &>/dev/null && echo "installpkg ✓" && return
    command -v urpmi &>/dev/null && urpmi --version &>/dev/null && echo "urpmi ✓" && return
    command -v pisi &>/dev/null && pisi --version &>/dev/null && echo "pisi ✓" && return
    command -v cast &>/dev/null && echo "cast ✓" && return
    command -v prt-get &>/dev/null && echo "prt-get ✓" && return
    command -v Compile &>/dev/null && echo "Compile ✓" && return
    command -v tce-load &>/dev/null && echo "tce ✓" && return
    command -v petget &>/dev/null && echo "petget ✓" && return
    command -v guix &>/dev/null && guix --version &>/dev/null && echo "guix ✓" && return
    
    # Fallback: detect by distro but mark as broken since commands failed
    if [ -f /etc/os-release ]; then
        case "$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')" in
            ubuntu|debian|mint|kali|pop|elementary|zorin|mx|deepin|parrot|tails|raspbian|devuan) echo "apt ✗" ;;
            fedora|rhel|centos|rocky|alma|oracle|scientific|amazonlinux) 
                # Check for microdnf as fallback for dnf
                if command -v microdnf &>/dev/null && microdnf --version &>/dev/null; then
                    echo "dnf ✗ → microdnf ✓"
                else
                    echo "dnf ✗"
                fi
                ;;
            opensuse*|sles|sled) echo "zypper ✗" ;;
            arch|manjaro|endeavouros|artix|garuda|blackarch) echo "pacman ✗" ;;
            alpine|postmarket) echo "apk ✗" ;;
            gentoo|funtoo|calculate|sabayon) echo "emerge ✗" ;;
            void) echo "xbps ✗" ;;
            nixos) echo "nix ✗" ;;
            solus) echo "eopkg ✗" ;;
            clear-linux-os) echo "swupd ✗" ;;
            slackware) echo "installpkg ✗" ;;
            mageia|openmandriva) echo "urpmi ✗" ;;
            pardus) echo "pisi ✗" ;;
            guix) echo "guix ✗" ;;
            *) echo "unknown ✗" ;;
        esac
    else
        echo "unknown ✗"
    fi
}

# Local IP detection
get_local_ip() {
    if command -v ip &>/dev/null; then
        local ip=$(ip -4 addr show eth0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)
        [ -z "$ip" ] && ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -n1)
        [ -n "$ip" ] && echo "$ip" && return
    fi
    
    command -v hostname &>/dev/null && {
        local ip=$(hostname -i 2>/dev/null | awk '{print $1}')
        [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ] && echo "$ip" && return
    }
    
    echo "iproute2 needed"
}

# Public IP detection
get_public_ip() {
    command -v curl &>/dev/null || { echo "curl needed"; return; }
    
    local ip=$(timeout 2 curl -s https://ipinfo.io/ip 2>/dev/null ||
               timeout 2 curl -s https://ipconfig.io 2>/dev/null ||
               timeout 2 curl -s https://api.ipify.org 2>/dev/null)
    
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "$ip" || echo "curl needed"
}

# Timezone detection
get_timezone() {
    [ -f /etc/timezone ] && cat /etc/timezone && return
    [ -L /etc/localtime ] && readlink /etc/localtime | sed 's|.*/zoneinfo/||' && return
    command -v timedatectl &>/dev/null && timedatectl show --property=Timezone --value 2>/dev/null && return
    echo "${TZ:-UTC}"
}

# Display system info
echo ""
echo -e "${WHITE}$(grep '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"') - $(get_container)${NC}"
echo -e "    ${YELLOW}🖥️${NC}  ${ORANGE}Version:${NC} ${BRIGHT_GREEN}$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')${NC}"
echo -e "    ${YELLOW}🏠${NC}  ${ORANGE}Hostname:${NC} ${BRIGHT_GREEN}$(hostname)${NC}"
echo -e "    ${YELLOW}👤${NC}  ${ORANGE}User:${NC} ${BRIGHT_GREEN}$(whoami)${NC}"
echo -e "    ${YELLOW}📦${NC}  ${ORANGE}Package:${NC} ${BRIGHT_GREEN}$(get_pkg_mgr)${NC}"
echo -e "    ${YELLOW}⚙️${NC}  ${ORANGE}Services:${NC} ${BRIGHT_GREEN}$(get_init_system)${NC}"
echo -e "    ${YELLOW}🌍${NC}  ${ORANGE}Timezone:${NC} ${BRIGHT_GREEN}$(get_timezone)${NC}"
echo -e "    ${YELLOW}💡${NC}  ${ORANGE}Local IP:${NC} ${BRIGHT_GREEN}$(get_local_ip)${NC}"
echo -e "    ${YELLOW}🌐${NC}  ${ORANGE}Public IP:${NC} ${BRIGHT_GREEN}$(get_public_ip)${NC}"
echo ""
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

# Environment Detection (Containers + VMs)
get_environment() {
    # Container detection first (highest priority)
    [ -f /.dockerenv ] && echo "Docker" && return
    [ -n "${container}" ] && echo "systemd-nspawn" && return
    
    # LXC detection
    if [ -f /proc/1/environ ] && grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
        echo "LXC" && return
    fi
    if [ -f /proc/1/cgroup ] && grep -q "/lxc/" /proc/1/cgroup 2>/dev/null; then
        echo "LXC" && return
    fi
    
    # VM detection using systemd-detect-virt (most reliable)
    if cmd_available systemd-detect-virt; then
        local virt_type=$(systemd-detect-virt 2>/dev/null)
        case "$virt_type" in
            # Containers
            lxc*) echo "LXC" && return ;;
            docker) echo "Docker" && return ;;
            systemd-nspawn) echo "systemd-nspawn" && return ;;
            # VMs
            kvm|qemu) echo "VM (KVM/QEMU)" && return ;;
            vmware) echo "VM (VMware)" && return ;;
            virtualbox) echo "VM (VirtualBox)" && return ;;
            xen) echo "VM (Xen)" && return ;;
            microsoft) echo "VM (Hyper-V)" && return ;;
            oracle) echo "VM (VirtualBox)" && return ;;
            *) [ "$virt_type" != "none" ] && echo "VM ($virt_type)" && return ;;
        esac
    fi
    
    # Manual VM detection via DMI/SMBIOS
    local dmi_vendor=$(safe_read /sys/class/dmi/id/sys_vendor)
    local dmi_product=$(safe_read /sys/class/dmi/id/product_name)
    local dmi_version=$(safe_read /sys/class/dmi/id/product_version)
    
    # Check for common VM indicators
    case "$dmi_vendor" in
        *QEMU*) echo "VM (QEMU)" && return ;;
        *VMware*) echo "VM (VMware)" && return ;;
        *VirtualBox*) echo "VM (VirtualBox)" && return ;;
        *Microsoft*) 
            case "$dmi_product" in
                *Virtual*) echo "VM (Hyper-V)" && return ;;
            esac
            ;;
        *Xen*) echo "VM (Xen)" && return ;;
        *innotek*) echo "VM (VirtualBox)" && return ;;
    esac
    
    case "$dmi_product" in
        *KVM*) echo "VM (KVM)" && return ;;
        *QEMU*) echo "VM (QEMU)" && return ;;
        *VMware*) echo "VM (VMware)" && return ;;
        *VirtualBox*) echo "VM (VirtualBox)" && return ;;
        *Virtual*Machine*) echo "VM (Hyper-V)" && return ;;
    esac
    
    # Check CPU flags for hypervisor bit
    if [ -f /proc/cpuinfo ] && grep -q "^flags.*hypervisor" /proc/cpuinfo 2>/dev/null; then
        echo "VM (Unknown)" && return
    fi
    
    # Check for virtualization-specific devices/modules
    if [ -d /proc/xen ]; then
        echo "VM (Xen)" && return
    fi
    
    # Check for VM-specific kernel modules
    if [ -f /proc/modules ]; then
        if grep -q "^vmw_" /proc/modules 2>/dev/null; then
            echo "VM (VMware)" && return
        fi
        if grep -q "^vboxguest\|^vboxsf" /proc/modules 2>/dev/null; then
            echo "VM (VirtualBox)" && return
        fi
    fi
    
    # Final fallback - check BIOS date for VM indicators
    local bios_date=$(safe_read /sys/class/dmi/id/bios_date)
    case "$bios_date" in
        *01/01/2011*|*04/01/2014*) echo "VM (QEMU)" && return ;;
    esac
    
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
    
    echo "iproute2"
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
    printf "${WHITE}%s - %s${NC}\n" "$(get_os_name)" "$(get_environment)"
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
