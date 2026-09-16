#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Host Pre-Install & Optimization                #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

basefolder="/opt/appdata"
template_dir="/opt/dockserver/preinstall/templates/local"
env_file="$basefolder/compose/.env"

if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
fi
SERVER_MODE="${SERVER_MODE:-cloud}"

oldsinstall() {
    oldsolutions="plexguide cloudbox gooby sudobox sbox pandaura salty"
    for i in ${oldsolutions}; do
        folders="/var/ /opt/ /home/ /srv/"
        for ii in ${folders}; do
            show=$(find "$ii" -maxdepth 2 -type d -name "$i" -print 2>/dev/null || true)
            if [[ -n "$show" ]]; then
                echo -e "${RED}Legacy installation found at $show (${i}).${NC}"
                echo "Please install on a fresh server or clean previous installations."
                read -erp "Type 'confirm' to continue anyway, or press Ctrl+C to abort: " input
                if [[ "$input" != "confirm" ]]; then exit 1; fi
            fi
        done
    done
}

proxydel() {
    delproxy="apache2 nginx"
    for i in ${delproxy}; do
        if systemctl is-active --quiet "$i" 2>/dev/null; then
            systemctl stop "$i" 2>/dev/null || true
            systemctl disable "$i" 2>/dev/null || true
            apt-get remove -yqq "$i" 2>/dev/null || true
            apt-get purge -yqq "$i" 2>/dev/null || true
        fi
    done
}

setup_directories() {
    echo -e "${BLUE}Creating required media and application directories...${NC}"
    folder="/mnt"
    mkdir -p "$folder"/{unionfs,downloads,incomplete,torrent,nzb} \
             "$folder"/{incomplete,downloads}/{nzb,torrent}/{complete,temp,movies,tv,tv4k,movies4k,movieshdr,tvhdr,remux} \
             "$folder"/downloads/torrent/{temp,complete}/{movies,tv,tv4k,movies4k,movieshdr,tvhdr,remux} \
             "$folder"/{torrent,nzb}/watch

    chmod -R a=rx,u+w "$folder" 2>/dev/null || true
    chown -hR 1000:1000 "$folder" 2>/dev/null || true

    mkdir -p "$basefolder"/{compose,system}
    chmod -R a=rx,u+w "$basefolder" 2>/dev/null || true
    chown -hR 1000:1000 "$basefolder" 2>/dev/null || true
}

configure_sysctl() {
    echo -e "${BLUE}Configuring kernel TCP BBR and buffer limits...${NC}"
    config="/etc/sysctl.d/99-sysctl.conf"
    touch "$config"

    # Set TCP BBR and networking performance
    grep -qE 'net.core.default_qdisc=fq' "$config" || echo 'net.core.default_qdisc=fq' >> "$config"
    grep -qE 'net.ipv4.tcp_congestion_control=bbr' "$config" || echo 'net.ipv4.tcp_congestion_control=bbr' >> "$config"
    grep -qE 'fs.file-max' "$config" || echo 'fs.file-max = 2097152' >> "$config"

    sysctl -p "$config" -q 2>/dev/null || true
}

configure_dns() {
    # If Local server mode, do not modify Netplan or DNS to preserve internal LAN/mDNS resolution
    if [[ "$SERVER_MODE" == "local" ]]; then
        echo -e "${YELLOW}Server mode is LOCAL: Skipping Netplan DNS overrides to preserve local LAN resolution.${NC}"
        return 0
    fi

    # Cloud server mode: Safely apply Quad9 DNS if Netplan is present and has Hetzner default IPs
    if [[ -d "/etc/netplan" ]]; then
        mapfile -t FILE < <(find /etc/netplan -type f \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null)
        for NETYAML in "${FILE[@]}"; do
            sed -i 's/185.12.64.1/9.9.9.9/' "$NETYAML" 2>/dev/null || true
            sed -i 's/185.12.64.2/149.112.112.112/' "$NETYAML" 2>/dev/null || true
        done
        netplan apply 2>/dev/null || true
    fi
}

install_packages() {
    echo -e "${BLUE}Updating system packages and installing dependencies...${NC}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -yqq

    local packages=(
        software-properties-common rsync pciutils lshw nano fuse curl wget
        tar pigz pv iptables ipset fail2ban jq ca-certificates gnupg python3
    )
    apt-get install -yqq "${packages[@]}"
}

install_docker() {
    echo -e "${BLUE}Installing Docker Engine & Docker Compose v2...${NC}"
    if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        export NEEDRESTART_MODE=a
        local lsb_dist="ubuntu"
        if [[ -r /etc/os-release ]]; then
            local os_id="$(. /etc/os-release && echo "$ID")"
            local os_like="$(. /etc/os-release && echo "${ID_LIKE:-}")"
            if [[ "$os_id" == "debian" || "$os_like" =~ debian ]]; then
                lsb_dist="debian"
            else
                lsb_dist="ubuntu"
            fi
        fi

        install -m 0755 -d /etc/apt/keyrings

        # Clean up lingering socket/service if replacing existing packages
        systemctl stop docker.socket docker.service 2>/dev/null || true
        systemctl daemon-reload 2>/dev/null || true

        if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
            curl -fsSL "https://download.docker.com/linux/${lsb_dist}/gpg" -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
        fi

        local codename
        codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
        if [[ -z "$codename" ]] && command -v lsb_release >/dev/null 2>&1; then
            codename="$(lsb_release -cs)"
        fi
        if [[ -z "$codename" ]]; then
            if [[ "$lsb_dist" == "debian" ]]; then
                codename="bookworm"
            else
                codename="noble"
            fi
        fi

        # Live probe: if Docker repository does not exist for this codename (e.g. Ubuntu 26 / non-LTS releases),
        # fallback to verified LTS to prevent apt 404 errors
        local check_url="https://download.docker.com/linux/${lsb_dist}/dists/${codename}/Release"
        if ! curl -fsSL --max-time 5 --head "$check_url" >/dev/null 2>&1; then
            if [[ "$lsb_dist" == "debian" ]]; then
                codename="bookworm"
            else
                codename="noble"
            fi
        fi
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${lsb_dist} ${codename} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update -yqq
        apt-get install -yqq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
            docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin crun || apt-get install -f -yqq || true

        systemctl daemon-reload 2>/dev/null || true
        systemctl unmask docker.service docker.socket 2>/dev/null || true
        systemctl enable docker.service 2>/dev/null || true
        systemctl restart docker.service 2>/dev/null || systemctl start docker.service 2>/dev/null || true
    fi

    # Backwards compatibility symlink for legacy scripts
    if [[ ! -f /usr/bin/docker-compose ]]; then
        if [[ -f /usr/libexec/docker/cli-plugins/docker-compose ]]; then
            ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose
        fi
    fi

    # Configure Docker daemon (preserve existing configuration if present)
    mkdir -p /etc/docker
    if [[ ! -f /etc/docker/daemon.json && -f "${template_dir}/daemon.j2" ]]; then
        cp -f "${template_dir}/daemon.j2" /etc/docker/daemon.json
        if [[ "$SERVER_MODE" == "local" ]]; then
            # In local mode, remove hardcoded Quad9 DNS so containers use host LAN DNS
            sed -i '/"dns":/d' /etc/docker/daemon.json 2>/dev/null || true
        fi
    fi
    systemctl reload-or-restart docker.service 2>/dev/null || true
    systemctl enable docker.service 2>/dev/null || true

    # Install local-persist plugin for unionfs volume
    if ! docker volume ls | grep -q 'unionfs'; then
        curl --silent -fsSL https://raw.githubusercontent.com/dockserver/local-persist/master/scripts/install.sh | bash >/dev/null 2>&1 || true
        docker volume create -d local-persist -o mountpoint=/mnt --name=unionfs 2>/dev/null || true
    fi

    # Create proxy network
    if ! docker network ls | grep -q 'proxy'; then
        docker network create --driver=bridge proxy 2>/dev/null || true
    fi
}

install_ansible() {
    # Install ansible from standard repositories on Ubuntu 22.04, 24.04 and Debian 12
    if ! command -v ansible >/dev/null 2>&1; then
        echo -e "${BLUE}Installing Ansible...${NC}"
        apt-get install -yqq ansible dialog python3-lxml 2>/dev/null || true
    fi

    mkdir -p /etc/ansible/inventories
    cat > /etc/ansible/inventories/local << 'EOF'
[local]
127.0.0.1 ansible_connection=local
EOF

    cat > /etc/ansible/ansible.cfg << 'EOF'
[defaults]
deprecation_warnings = False
command_warnings = False
force_color = True
inventory = /etc/ansible/inventories/local
retry_files_enabled = False
EOF
}

setup_security() {
    echo -e "${BLUE}Configuring security rules (Fail2ban, limits, ipset)...${NC}"
    # Security limits
    sed -i '/hard nofile/ d' /etc/security/limits.conf
    sed -i '/soft nofile/ d' /etc/security/limits.conf
    echo -e "* hard nofile 65536\n* soft nofile 32768" >> /etc/security/limits.conf

    # Fail2ban filters
    mkdir -p /etc/fail2ban/filter.d
    cat > /etc/fail2ban/filter.d/log4j-jndi.conf << 'EOF'
[log4j-jndi]
maxretry = 1
enabled = true
port = 80,443
logpath = /opt/appdata/traefik/logs/traefik.log
EOF

    cat > /etc/fail2ban/filter.d/authelia.conf << 'EOF'
[authelia]
enabled = true
port = http,https,9091
filter = authelia
logpath = /opt/appdata/authelia/authelia.log
maxretry = 3
bantime = 24h
findtime = 1h
chain = DOCKER-USER
EOF

    if systemctl is-active --quiet fail2ban; then
        systemctl reload-or-restart fail2ban.service 2>/dev/null || true
    fi

    # IPSet malicious bot blocking
    if command -v ipset >/dev/null 2>&1; then
        ipset -q flush ips 2>/dev/null || true
        ipset -q create ips hash:net 2>/dev/null || true
        for ip in $(curl --compressed -sSL https://raw.githubusercontent.com/scriptzteam/IP-BlockList-v4/master/ips.txt 2>/dev/null | grep -v "#" | grep -v -E "\s[1-2]$" | cut -f 1 | head -n 5000); do
            ipset add ips "$ip" 2>/dev/null || true
        done
        iptables -C INPUT -m set --match-set ips src -j DROP 2>/dev/null || iptables -I INPUT -m set --match-set ips src -j DROP 2>/dev/null || true
    fi
}

main() {
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}    🚀  DockServer Host Pre-Installation & Optimization                   ${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    oldsinstall
    proxydel
    install_packages
    setup_directories
    configure_sysctl
    configure_dns
    install_docker
    install_ansible
    setup_security

    # LXC environment configuration
    if [[ "$(systemd-detect-virt 2>/dev/null)" == "lxc" ]]; then
        if [[ -f "/opt/dockserver/preinstall/installer/subinstall/lxc.sh" ]]; then
            bash "/opt/dockserver/preinstall/installer/subinstall/lxc.sh" || true
        fi
    fi

    # Hardware Acceleration & GPU configuration
    if [[ -d "/dev/dri" || $(lspci 2>/dev/null | grep -iE 'vga|display|3d|2d' | grep -iE 'nvidia|intel|amd|ati|radeon' || true) ]]; then
        if [[ -f "${template_dir}/gpu.sh" ]]; then
            bash "${template_dir}/gpu.sh" || true
        fi
    fi

    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}    🚀  Pre-Installation Complete! Ready for Edge Gateway setup.         ${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

main "$@"
