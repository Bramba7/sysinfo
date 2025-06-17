#!/bin/bash
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
