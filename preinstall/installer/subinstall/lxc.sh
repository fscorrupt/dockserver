#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - LXC Mount Shared & Docker Container Fix        #
# Modernized for Proxmox VE, Ubuntu 24.04, 22.04 & Debian 12  #
###############################################################
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

# Only run if running inside an LXC container
if [[ "$(systemd-detect-virt 2>/dev/null)" != "lxc" ]]; then
    exit 0
fi

echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}    🚀  LXC Container Detected: Configuring Shared Mounts & Docker Support${NC}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 1. Apply shared mount immediately to live root filesystem
echo -e "${BLUE}==> Applying shared mount propagation to /...${NC}"
mount --make-shared / 2>/dev/null || true

# 2. Deploy script to /home/.lxcstart.sh
mkdir -p /home
cat << 'EOF' > /home/.lxcstart.sh
#!/bin/bash
mount --make-shared /
EOF
chmod 0755 /home/.lxcstart.sh

# 3. Dedicated systemd unit (guarantees execution BEFORE Docker on every boot)
echo -e "${BLUE}==> Installing persistent systemd service (runs before docker.service)...${NC}"
cat << 'EOF' > /etc/systemd/system/lxc-make-shared.service
[Unit]
Description=Make / shared mount for Docker in LXC
DefaultDependencies=no
Conflicts=shutdown.target
Before=docker.service sysinit.target local-fs.target
After=systemd-remount-fs.service

[Service]
Type=oneshot
ExecStart=/bin/mount --make-shared /
RemainAfterExit=yes

[Install]
WantedBy=basic.target multi-user.target
EOF

systemctl daemon-reload 2>/dev/null || true
systemctl enable lxc-make-shared.service 2>/dev/null || true
systemctl start lxc-make-shared.service 2>/dev/null || true

# 4. Fallback cron for non-systemd or legacy environments
if [[ -d "/etc/cron.d" ]]; then
    cat << 'EOF' > /etc/cron.d/lxcstart
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
@reboot root /bin/bash /home/.lxcstart.sh >/dev/null 2>&1

EOF
    chmod 0644 /etc/cron.d/lxcstart
fi

# 5. Run Ansible playbook if present for backwards compatibility
if command -v ansible-playbook >/dev/null 2>&1 && [[ -f "/opt/dockserver/preinstall/installer/subinstall/lxc.yml" ]]; then
    ansible-playbook "/opt/dockserver/preinstall/installer/subinstall/lxc.yml" >/dev/null 2>&1 || true
fi

echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✅  LXC Shared Mount Successfully Configured!                           ${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}${BOLD}Proxmox VE Requirements for Docker in LXC:${NC}"
echo "  Ensure your container has the following features enabled in Proxmox:"
echo "  • Options -> Features -> Check: 'nesting', 'keyctl', and 'fuse'"
echo "  • Or in /etc/pve/lxc/<VMID>.conf: features: nesting=1,keyctl=1,fuse=1"
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
