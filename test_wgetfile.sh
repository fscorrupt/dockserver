#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Testing Bootstrap Installer                    #
# Configured for fork: https://github.com/fscorrupt/dockserver #
###############################################################
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Please run this installer as root or with sudo.${NC}"
    exit 1
fi

echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}    🧪    DockServer TEST Installer (Fork: fscorrupt)       ${NC}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Update and install prerequisite tools
echo -e "${BLUE}==> Installing prerequisite packages...${NC}"
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export PYTHONWARNINGS="ignore"
apt-get update -yqq
apt-get install -yqq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" curl git jq tar pigz pv rsync ca-certificates gnupg

# Docker installation routine
install_docker_packages() {
    echo -e "${BLUE}==> Installing/Repairing Docker Engine & Docker Compose v2...${NC}"
    install -m 0755 -d /etc/apt/keyrings

    # Clean up lingering socket/service if replacing existing packages
    systemctl stop docker.socket docker.service 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true

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

    if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
        curl -fsSL "https://download.docker.com/linux/${lsb_dist}/gpg" -o /etc/apt/keyrings/docker.asc 2>/dev/null || true
        chmod a+r /etc/apt/keyrings/docker.asc 2>/dev/null || true
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
}

ensure_docker_daemon() {
    if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
        install_docker_packages
    fi

    if docker info >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${BLUE}==> Docker daemon is not active. Automatically starting Docker service...${NC}"
    systemctl unmask docker.service docker.socket containerd 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable --now containerd 2>/dev/null || true
    systemctl restart containerd 2>/dev/null || systemctl start containerd 2>/dev/null || true
    systemctl enable --now docker.socket docker.service 2>/dev/null || true
    systemctl restart docker.service 2>/dev/null || systemctl start docker.service 2>/dev/null || true

    local attempts=15
    while [[ $attempts -gt 0 ]]; do
        if docker info >/dev/null 2>&1; then
            echo -e "${GREEN}==> Docker daemon is active and responsive!${NC}"
            return 0
        fi
        sleep 1
        attempts=$((attempts - 1))
    done

    # Self-healing fallback if daemon.json was corrupt
    if [[ -f /etc/docker/daemon.json ]]; then
        echo -e "${YELLOW}==> Testing recovery by clearing /etc/docker/daemon.json...${NC}"
        mv -f /etc/docker/daemon.json /etc/docker/daemon.json.corrupt_bak 2>/dev/null || true
        systemctl restart docker.service 2>/dev/null || true
        sleep 3
        if docker info >/dev/null 2>&1; then
            echo -e "${GREEN}==> Docker recovered successfully!${NC}"
            return 0
        fi
    fi

    echo -e "${YELLOW}==> Docker daemon still inactive. Running automated package repair...${NC}"
    install_docker_packages
    systemctl restart containerd 2>/dev/null || true
    systemctl restart docker.service 2>/dev/null || true
    sleep 3

    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}==> Docker daemon is active and responsive!${NC}"
        return 0
    else
        echo -e "${RED}Error: Docker daemon could not be started automatically.${NC}"
        journalctl -u docker.service -n 15 --no-pager 2>/dev/null || true
        return 1
    fi
}

# Ensure Docker daemon is active and responsive
ensure_docker_daemon

# Ensure default external proxy network exists
if ! docker network inspect proxy >/dev/null 2>&1; then
    echo -e "${BLUE}==> Creating default external Docker network 'proxy'...${NC}"
    docker network create --driver=bridge proxy 2>/dev/null || true
fi

# Compatibility symlink
if [[ ! -f /usr/bin/docker-compose && -f /usr/libexec/docker/cli-plugins/docker-compose ]]; then
    ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose
fi

# Target fork repository and branch
dockserver_dir="/opt/dockserver"
test_repo="${DOCKSERVER_REPO:-https://github.com/fscorrupt/dockserver.git}"
test_branch="${DOCKSERVER_BRANCH:-master}"

if [[ -d "$dockserver_dir/.git" ]]; then
    echo -e "${BLUE}==> Existing /opt/dockserver detected. Updating from $test_repo ($test_branch)...${NC}"
    git -C "$dockserver_dir" remote set-url origin "$test_repo" 2>/dev/null || true
    git -C "$dockserver_dir" fetch origin "$test_branch"
    git -C "$dockserver_dir" checkout -f "$test_branch"
    git -C "$dockserver_dir" reset --hard "origin/$test_branch"
else
    echo -e "${BLUE}==> Fresh clone of $test_repo ($test_branch) into $dockserver_dir...${NC}"
    rm -rf "$dockserver_dir"
    mkdir -p "$dockserver_dir"
    git clone -b "$test_branch" "$test_repo" "$dockserver_dir"
fi

# Link CLI executable
if [[ -f "$dockserver_dir/.installer/dockserver" ]]; then
    chmod +x "$dockserver_dir/.installer/dockserver"
    cp -f "$dockserver_dir/.installer/dockserver" /usr/bin/dockserver
    chmod +x /usr/bin/dockserver
    if [[ ! -L /bin && -d /bin && ! -f /bin/dockserver ]]; then
        ln -sf /usr/bin/dockserver /bin/dockserver 2>/dev/null || true
    fi
fi

# Automatically run Host Pre-Installation & Optimization if not already done
if [[ ! -f "/opt/appdata/.preinstalled" && -f "$dockserver_dir/preinstall/install.sh" ]]; then
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}==> Running automated Host Pre-Installation & Optimization...${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    bash "$dockserver_dir/preinstall/install.sh"
fi

echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}    🧪    DockServer Test Environment Ready!                ${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "   Repository: $test_repo"
echo "   Branch:     $test_branch"
echo ""
echo "   To launch the interactive control panel:"
echo "     dockserver -i"
echo ""
echo "   To upgrade an existing installation:"
echo "     dockserver -m"
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
