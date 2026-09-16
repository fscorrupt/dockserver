#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Automated Docker Daemon Health & Self-Healing  #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

install_docker_packages() {
    echo -e "${BLUE}==> Installing/Repairing Docker Engine & Compose plugin...${NC}"
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    install -m 0755 -d /etc/apt/keyrings

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

ensure_proxy_network() {
    local net_name="${DOCKERNETWORK:-proxy}"
    if ! docker network inspect "$net_name" >/dev/null 2>&1; then
        echo -e "${BLUE}==> Creating default external Docker network '${net_name}'...${NC}"
        docker network create --driver=bridge "$net_name" 2>/dev/null || true
    fi
}

ensure_docker_daemon() {
    # 1. Check if docker and docker compose commands exist
    if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
        install_docker_packages
    fi

    # 2. Check if Docker daemon is already alive and responsive
    if docker info >/dev/null 2>&1; then
        ensure_proxy_network
        return 0
    fi

    echo -e "${BLUE}==> Docker daemon is not active. Automatically starting Docker service...${NC}"
    systemctl unmask docker.service docker.socket containerd 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable --now containerd 2>/dev/null || true
    systemctl restart containerd 2>/dev/null || systemctl start containerd 2>/dev/null || true
    systemctl enable --now docker.socket docker.service 2>/dev/null || true
    systemctl restart docker.service 2>/dev/null || systemctl start docker.service 2>/dev/null || true

    # 3. Active wait loop up to 15 seconds
    local attempts=15
    while [[ $attempts -gt 0 ]]; do
        if docker info >/dev/null 2>&1; then
            echo -e "${GREEN}==> Docker daemon is active and responsive!${NC}"
            ensure_proxy_network
            return 0
        fi
        sleep 1
        attempts=$((attempts - 1))
    done

    # 4. Self-healing fallback: Check if corrupt /etc/docker/daemon.json is crashing dockerd
    if [[ -f /etc/docker/daemon.json ]]; then
        echo -e "${YELLOW}==> Docker failed to start. Testing recovery by resetting /etc/docker/daemon.json...${NC}"
        mv -f /etc/docker/daemon.json /etc/docker/daemon.json.corrupt_bak 2>/dev/null || true
        systemctl restart docker.service 2>/dev/null || true
        sleep 3
        if docker info >/dev/null 2>&1; then
            echo -e "${GREEN}==> Docker recovered successfully with default configuration!${NC}"
            ensure_proxy_network
            return 0
        fi
    fi

    # 5. Reinstall/repair packages if still not running
    echo -e "${YELLOW}==> Docker daemon still inactive. Running automated package repair...${NC}"
    install_docker_packages
    systemctl restart containerd 2>/dev/null || true
    systemctl restart docker.service 2>/dev/null || true
    sleep 3

    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}==> Docker daemon is active and responsive!${NC}"
        ensure_proxy_network
        return 0
    else
        echo -e "${RED}Error: Docker daemon could not be started automatically.${NC}"
        journalctl -u docker.service -n 15 --no-pager 2>/dev/null || true
        return 1
    fi
}

# If script executed directly, run check
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    ensure_docker_daemon
fi
