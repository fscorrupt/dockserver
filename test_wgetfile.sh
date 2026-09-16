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
apt-get update -yqq
apt-get install -yqq curl git jq tar pigz pv rsync ca-certificates gnupg

# Install Docker Engine & Compose Plugin if not present
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    echo -e "${BLUE}==> Installing modern Docker Engine & Docker Compose v2...${NC}"
    install -m 0755 -d /etc/apt/keyrings

    lsb_dist="ubuntu"
    if [[ -r /etc/os-release ]]; then
        lsb_dist="$(. /etc/os-release && echo "$ID")"
    fi

    if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
        curl -fsSL "https://download.docker.com/linux/${lsb_dist}/gpg" -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
    fi

    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${lsb_dist} ${codename} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -yqq
    apt-get install -yqq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
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
    ln -sf /usr/bin/dockserver /bin/dockserver
    chmod +x /usr/bin/dockserver /bin/dockserver
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
