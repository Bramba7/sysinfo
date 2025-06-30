#!/bin/sh
# More actions
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
    # Test both existence AND functionality in one go
    command -v apt >/dev/null 2>&1 && apt --version >/dev/null 2>&1 && echo "apt ✓" && return
    command -v brew >/dev/null 2>&1 && brew --version >/dev/null 2>&1 && echo "brew ✓" && return
    command -v dnf &>/dev/null 2>&1 && dnf --version &>/dev/null 2>&1 && echo "dnf ✓" && return
    command -v yum &>/dev/null 2>&1 && yum --version &>/dev/null 2>&1 && echo "yum ✓" && return
    command -v zypper &>/dev/null 2>&1 && zypper --version &>/dev/null 2>&1 && echo "zypper ✓" && return
    command -v pacman &>/dev/null 2>&1 && pacman --version &>/dev/null 2>&1 && echo "pacman ✓" && return
    command -v apk &>/dev/null 2>&1 && apk --version &>/dev/null 2>&1 && echo "apk ✓" && return
    command -v emerge &>/dev/null 2>&1 && emerge --version &>/dev/null 2>&1 && echo "emerge ✓" && return
    command -v xbps-install &>/dev/null 2>&1 && xbps-install --version &>/dev/null 2>&1 && echo "xbps ✓" && return
    command -v nix-env &>/dev/null 2>&1 && nix-env --version &>/dev/null 2>&1 && echo "nix ✓" && return
    command -v eopkg &>/dev/null 2>&1 && eopkg --version &>/dev/null 2>&1 && echo "eopkg ✓" && return
    command -v swupd &>/dev/null 2>&1 && swupd --version &>/dev/null 2>&1 && echo "swupd ✓" && return
    command -v installpkg &>/dev/null 2>&1 && echo "installpkg ✓" 2>&1 && return
    command -v urpmi &>/dev/null 2>&1 && urpmi --version &>/dev/null 2>&1 && echo "urpmi ✓" && return
    command -v pisi &>/dev/null 2>&1 && pisi --version &>/dev/null 2>&1 && echo "pisi ✓" && return
    command -v cast &>/dev/null 2>&1 && echo "cast ✓" 2>&1 && return
    command -v prt-get &>/dev/null 2>&1 && echo "prt-get ✓" 2>&1 && return
    command -v Compile &>/dev/null 2>&1 && echo "Compile ✓" 2>&1 && return
    command -v tce-load &>/dev/null 2>&1 && echo "tce ✓" 2>&1 && return
    command -v petget &>/dev/null 2>&1 && echo "petget ✓" 2>&1 && return
    command -v guix &>/dev/null 2>&1 && guix --version &>/dev/null 2>&1 && echo "guix ✓" && return
    
    # Fallback: detect by distro but mark as broken since commands failed
    if [ -f /etc/os-release ]; then
        case "$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')" in
            ubuntu|debian|mint|kali|pop|elementary|zorin|mx|deepin|parrot|tails|raspbian|devuan) echo "apt ✗" ;;
            fedora|rhel|centos|rocky|alma|oracle|scientific|amazonlinux) 
                # Check for microdnf as fallback for dnf
                if command -v microdnf &>/dev/null && microdnf --help &>/dev/null; then
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

# Init System Detection
get_init_system() {
    # Check systemd first (most common)
    if cmd_exists systemctl; then
        echo "systemctl ✓" && return
    fi
    
    # Darwin-specific init detection
    if cmd_exists systemsetup; then
        echo "systemsetup ✓" && return
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
    local ip

    # 1) Try hostname -I (Preferred in many Linux distros)
    if command -v hostname >/dev/null 2>&1; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
            echo "$ip"
            return 0
        fi
    fi
    
    # 2) Try ifconfig
    if command -v ifconfig >/dev/null 2>&1; then
        local iface interfaces status
        interfaces=$(ifconfig -a 2>/dev/null | awk -F: '/^[[:alnum:]]/ {print $1}')

        for iface in $interfaces; do
            [ "$iface" = "lo" ] && continue

            status=$(ifconfig "$iface" 2>/dev/null | awk '/status:/ {print $2}')
            if [ -n "$status" ] && [ "$status" != "active" ] && [ "$status" != "up" ]; then
                continue
            fi

            ip=$(ifconfig "$iface" 2>/dev/null \
                | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}')

            if [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ]; then
                echo "$ip"
                return 0
            fi
        done
    fi
    # 3) Try ip (iproute2)
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip -4 addr show scope global \
            | awk '/inet / && $2 !~ /^127\./ {split($2,a,"/"); print a[1]; exit}')
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
    fi

    # 5) Give up
    echo "* Install 'iproute2' (ip), 'net-tools' (ifconfig)"
    return 0
}

# Public IP Detection
get_public_ip() {
   # Check for curl or wget
   if command -v curl >/dev/null; then
       local ip=$(timeout 2 curl -s https://ipinfo.io/ip 2>/dev/null ||
                  timeout 2 curl -s https://ifconfig.io 2>/dev/null ||
                  timeout 2 curl -s https://api.ipify.org 2>/dev/null)
   elif command -v wget >/dev/null; then
       local ip=$(timeout 2 wget -qO- https://ipinfo.io/ip 2>/dev/null ||
                  timeout 2 wget -qO- https://ifconfig.io 2>/dev/null ||
                  timeout 2 wget -qO- https://api.ipify.org 2>/dev/null)
   else
       echo "curl/wget needed" && return
   fi
   
   # Use POSIX-compatible regex test
   case "$ip" in
       *[!0-9.]*) echo "network unavailable" ;;
       *.*.*.*)
           echo "$ip" | grep -q '^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$' && echo "$ip" || echo "network unavailable"
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
    printf "    ${YELLOW}🖥️${NC}\t${ORANGE}Version:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_os_version)"
    printf "    ${YELLOW}🏠${NC}\t${ORANGE}Hostname:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_hostname)"
    printf "    ${YELLOW}👤${NC}\t${ORANGE}User:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(whoami)"
    printf "    ${YELLOW}📦${NC}\t${ORANGE}Package:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_pkg_mgr)"
    printf "    ${YELLOW}📋${NC}\t${ORANGE}Services:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_init_system)"
    printf "    ${YELLOW}⏱️${NC}\t${ORANGE}Timezone:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_timezone)"
    printf "    ${YELLOW}📍${NC}\t${ORANGE}Local IP:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_local_ip)"
    printf "    ${YELLOW}🌍${NC}\t${ORANGE}Public IP:${NC} ${BRIGHT_GREEN}%s${NC}\n" "$(get_public_ip)"
    printf "\n"
}

# Execute main function
display_system_info
