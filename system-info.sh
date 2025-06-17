#!/bin/sh
# /etc/profile.d/01-system-info.sh

# For zsh users - add to ~/.zshrc:
#echo 'source /etc/profile.d/01-system-info.sh' >> ~/.zshrc


# Show for interactive shells or if TERM is set (Docker compatibility)
case "$-" in
    *i*) ;;
    *) [ -z "$TERM" ] && return ;;
esac

# Colors (only used ones)
YELLOW='\033[38;2;215;153;33m'
ORANGE='\033[38;2;214;93;14m'
BRIGHT_GREEN='\033[38;2;184;187;38m'
RED='\033[38;2;204;36;29m'
WHITE='\033[1;38;2;235;219;178m'
NC='\033[0m'

# Container/environment detection
get_container() {
    # Check for Docker first
    [ -f /.dockerenv ] && echo "Docker" && return
    
    # Check for systemd-nspawn
    [ -n "${container}" ] && echo "systemd-nspawn" && return
    [ -f /run/systemd/container ] && cat /run/systemd/container 2>/dev/null && return
    
    # Check for LXC - multiple methods
    # Method 1: Check /proc/1/environ for container=lxc
    if [ -f /proc/1/environ ]; then
        if grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
            echo "LXC" && return
        fi
    fi
    
    # Method 2: Check /proc/1/cgroup for lxc
    if [ -f /proc/1/cgroup ]; then
        if grep -q "/lxc/" /proc/1/cgroup 2>/dev/null; then
            echo "LXC" && return
        fi
    fi
    
    # Method 3: Check for LXC-specific files
    [ -f /proc/self/cgroup ] && grep -q "/lxc/" /proc/self/cgroup 2>/dev/null && echo "LXC" && return
    
    # Method 4: Check for LXC environment variables
    [ -n "$LXC_NAME" ] && echo "LXC" && return
    
    # Method 5: Check systemd for LXC
    if [ -f /run/systemd/container ]; then
        local container_type=$(cat /run/systemd/container 2>/dev/null)
        [ "$container_type" = "lxc" ] && echo "LXC" && return
    fi
    
    # Method 6: Check for virtualization detection
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        local virt=$(systemd-detect-virt 2>/dev/null)
        case "$virt" in
            lxc*) echo "LXC" && return ;;
            docker) echo "Docker" && return ;;
            systemd-nspawn) echo "systemd-nspawn" && return ;;
        esac
    fi
    
    # Default fallback
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
            fedora|rhel|centos|rocky|alma|oracle|scientific|amazonlinux) echo "dnf ✗" ;;
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

# Hostname detection with fallbacks
get_hostname() {
    # Try hostname command first
    if command -v hostname &>/dev/null; then
        local host=$(hostname 2>/dev/null)
        [ -n "$host" ] && echo "$host" && return
    fi
    
    # Fallback to /proc/sys/kernel/hostname
    if [ -f /proc/sys/kernel/hostname ]; then
        local host=$(cat /proc/sys/kernel/hostname 2>/dev/null)
        [ -n "$host" ] && echo "$host" && return
    fi
    
    # Fallback to /etc/hostname
    if [ -f /etc/hostname ]; then
        local host=$(cat /etc/hostname 2>/dev/null)
        [ -n "$host" ] && echo "$host" && return
    fi
    
    # Fallback to uname
    if command -v uname &>/dev/null; then
        local host=$(uname -n 2>/dev/null)
        [ -n "$host" ] && echo "$host" && return
    fi
    
    # Last resort - check HOSTNAME environment variable
    [ -n "$HOSTNAME" ] && echo "$HOSTNAME" && return
    
    echo "unknown"
}

# Local IP detection
get_local_ip() {
    if command -v ip &>/dev/null; then
        # Try eth0 first
        local ip=$(ip -4 addr show eth0 2>/dev/null | grep 'inet ' | head -n1 | sed 's/.*inet \([^/]*\).*/\1/')
        [ -n "$ip" ] && echo "$ip" && return
        
        # Try default route
        ip=$(ip route get 1 2>/dev/null | grep -o 'src [0-9.]*' | cut -d' ' -f2 | head -n1)
        [ -n "$ip" ] && echo "$ip" && return
        
        # Try any interface with inet
        ip=$(ip -4 addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -n1 | sed 's/.*inet \([^/]*\).*/\1/')
        [ -n "$ip" ] && echo "$ip" && return
    fi
    
    # Try hostname -i only if hostname command exists
    if command -v hostname &>/dev/null; then
        local ip=$(hostname -i 2>/dev/null | cut -d' ' -f1)
        [ -n "$ip" ] && [ "$ip" != "127.0.0.1" ] && echo "$ip" && return
    fi
    
    # Fallback: check /proc/net/fib_trie for local IPs
    if [ -f /proc/net/fib_trie ]; then
        local ip=$(grep -E '^\s+\|--\s+[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /proc/net/fib_trie 2>/dev/null | grep -v '127.0.0.1' | head -n1 | sed 's/.*-- \([0-9.]*\).*/\1/')
        [ -n "$ip" ] && echo "$ip" && return
    fi
    
    echo "iproute2 needed"
}

# Public IP detection with curl and wget fallback
get_public_ip() {
    local ip=""
    
    # Try curl first
    if command -v curl &>/dev/null; then
        ip=$(timeout 2 curl -s https://ipinfo.io/ip 2>/dev/null ||
             timeout 2 curl -s https://ipconfig.io 2>/dev/null ||
             timeout 2 curl -s https://api.ipify.org 2>/dev/null)
    # Fallback to wget if curl is not available
    elif command -v wget &>/dev/null; then
        ip=$(timeout 2 wget -qO- https://ipinfo.io/ip 2>/dev/null ||
             timeout 2 wget -qO- https://ipconfig.io 2>/dev/null ||
             timeout 2 wget -qO- https://api.ipify.org 2>/dev/null)
    else
        echo "curl/wget needed"
        return
    fi
    
    # Validate IP format
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
    else
        echo "curl/wget needed"
    fi
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
echo -e "    ${YELLOW}🏠${NC}  ${ORANGE}Hostname:${NC} ${BRIGHT_GREEN}$(get_hostname)${NC}"
echo -e "    ${YELLOW}👤${NC}  ${ORANGE}User:${NC} ${BRIGHT_GREEN}$(whoami)${NC}"
echo -e "    ${YELLOW}📦${NC}  ${ORANGE}Package:${NC} ${BRIGHT_GREEN}$(get_pkg_mgr)${NC}"
echo -e "    ${YELLOW}⚙️${NC}  ${ORANGE}Services:${NC} ${BRIGHT_GREEN}$(get_init_system)${NC}"
echo -e "    ${YELLOW}🌍${NC}  ${ORANGE}Timezone:${NC} ${BRIGHT_GREEN}$(get_timezone)${NC}"
echo -e "    ${YELLOW}💡${NC}  ${ORANGE}Local IP:${NC} ${BRIGHT_GREEN}$(get_local_ip)${NC}"
echo -e "    ${YELLOW}🌐${NC}  ${ORANGE}Public IP:${NC} ${BRIGHT_GREEN}$(get_public_ip)${NC}"
echo ""
