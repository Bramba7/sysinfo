# SysInfo

A clean system information display tool for terminals with an interactive installer.

## Features

- **System Overview**: OS, version, hostname, user details
- **Environment Info**: Package manager, services, timezone
- **Network Details**: Local and public IP addresses
- **Container Detection**: Docker, LXC, systemd-nspawn support
- **Multiple Install Options**: One-time test, command tool, or auto-start

## Quick Install

### Using curl
```bash
curl -sSL https://raw.githubusercontent.com/Bramba7/sysinfo/main/install-system-info.sh | sh
```

### Using wget
```bash
wget -qO- https://raw.githubusercontent.com/Bramba7/sysinfo/main/install-system-info.sh | sh
```

## Installation Options

The interactive installer provides three options:

1. **Quick Test** - Run once without installation
2. **Command Tool** - Install as `sysinfo` command
3. **Auto-start** - Show system info on every login

## Usage

After installing as command tool:
```bash
sysinfo
```

## Sample Output

```
Ubuntu 22.04 - Docker
    🖥️  Version: 22.04
    🏠  Hostname: web-server
    👤  User: ubuntu
    📦  Package: apt ✓
    📋  Services: systemctl ✓
    ⏱️  Timezone: UTC
    📍  Local IP: 172.17.0.2
    🌍  Public IP: 203.0.113.1
```

## Requirements

- POSIX-compatible shell
- `curl` or `wget`
- Root access for system-wide installation (options 2 & 3)

## Compatibility

- Linux distributions (Ubuntu, Debian, CentOS, Arch, Alpine, etc.)
- Container environments (Docker, LXC, systemd-nspawn)
- Cloud instances and VPS
- Bare metal servers
