#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Hardware Acceleration & GPU Setup              #
# Supports Intel QuickSync/Arc, NVIDIA & AMD Radeon/APU       #
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

HAS_INTEL=false
HAS_NVIDIA=false
HAS_AMD=false

# 1. Hardware Detection
PCI_OUTPUT=$(lspci 2>/dev/null | grep -iE 'vga|display|3d|2d' || true)

if echo "$PCI_OUTPUT" | grep -qi 'intel'; then
    HAS_INTEL=true
elif grep -qi 'intel' /proc/cpuinfo 2>/dev/null && [[ -d "/dev/dri" ]]; then
    HAS_INTEL=true
fi

if echo "$PCI_OUTPUT" | grep -qi 'nvidia'; then
    HAS_NVIDIA=true
fi

if echo "$PCI_OUTPUT" | grep -qiE 'amd|ati|radeon'; then
    HAS_AMD=true
fi

# 2. Configure User & Group Permissions for /dev/dri
setup_permissions() {
    echo -e "${BLUE}Configuring video and render group permissions...${NC}"
    groupadd -f video
    groupadd -f render

    local target_users=()
    if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
        target_users+=("$SUDO_USER")
    fi
    local user1000
    user1000=$(id -nu 1000 2>/dev/null || true)
    if [[ -n "$user1000" && ! " ${target_users[*]} " =~ " ${user1000} " ]]; then
        target_users+=("$user1000")
    fi

    for u in "${target_users[@]}"; do
        usermod -aG video,render "$u" 2>/dev/null || true
    done

    if [[ -d "/dev/dri" ]]; then
        chmod -R 755 /dev/dri 2>/dev/null || true
        chmod 666 /dev/dri/renderD* 2>/dev/null || true
        chmod 666 /dev/dri/card* 2>/dev/null || true
    fi
}

# 3. Intel QuickSync & Arc Setup
setup_intel() {
    echo -e "${CYAN}==> Configuring Intel QuickSync / iGPU / Arc...${NC}"

    # Hetzner server check: unblacklist i915 if blacklisted
    local hetzner_bl="/etc/modprobe.d/blacklist-hetzner.conf"
    if [[ -f "$hetzner_bl" ]] && grep -q '^blacklist i915' "$hetzner_bl"; then
        echo -e "${YELLOW}Hetzner server detected: Unblacklisting i915 driver in $hetzner_bl...${NC}"
        sed -i 's/^blacklist i915/#blacklist i915/g' "$hetzner_bl"
        if command -v update-grub >/dev/null 2>&1; then
            update-grub 2>/dev/null || true
        fi
    fi

    # Install VA-API and diagnostic tools
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -yqq
    apt-get install -yqq vainfo intel-media-va-driver-non-free 2>/dev/null || apt-get install -yqq vainfo intel-media-va-driver 2>/dev/null || true
    apt-get install -yqq intel-gpu-tools 2>/dev/null || true

    echo -e "${GREEN}Intel GPU tools and VA-API drivers installed.${NC}"
}

# 4. AMD Radeon & APU Setup
setup_amd() {
    echo -e "${CYAN}==> Configuring AMD Radeon / APU Hardware Acceleration...${NC}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -yqq
    apt-get install -yqq vainfo mesa-va-drivers mesa-vulkan-drivers 2>/dev/null || true
    apt-get install -yqq radeontop 2>/dev/null || true

    echo -e "${GREEN}AMD GPU VA-API drivers and diagnostic tools installed.${NC}"
}

# 5. NVIDIA Setup
setup_nvidia() {
    echo -e "${CYAN}==> Configuring NVIDIA Container Toolkit & Drivers...${NC}"

    # Modern official NVIDIA repository setup (libnvidia-container/stable/deb)
    if [[ ! -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]]; then
        mkdir -p /usr/share/keyrings
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
    fi

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -yqq
    apt-get install -yqq nvidia-container-toolkit 2>/dev/null || true

    # Configure Docker daemon safely using official nvidia-ctk CLI
    if command -v nvidia-ctk >/dev/null 2>&1; then
        echo -e "${BLUE}Configuring Docker daemon NVIDIA runtime via nvidia-ctk...${NC}"
        nvidia-ctk runtime configure --runtime=docker 2>/dev/null || true
        systemctl reload-or-restart docker.service 2>/dev/null || true
    fi

    # Check if NVIDIA driver is loaded
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo -e "${GREEN}NVIDIA driver is active:${NC}"
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || true
    else
        echo -e "${YELLOW}Notice: NVIDIA GPU detected, but nvidia-smi is not found.${NC}"
        echo -e "${YELLOW}To install host NVIDIA drivers on Ubuntu: sudo ubuntu-drivers install${NC}"
    fi
}

main() {
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}    🚀  DockServer Hardware Acceleration & GPU Setup                     ${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [[ "$HAS_INTEL" == "false" && "$HAS_NVIDIA" == "false" && "$HAS_AMD" == "false" ]]; then
        echo "No dedicated or integrated GPU detected. Setting standard /dev/dri permissions if present."
        setup_permissions
        return 0
    fi

    setup_permissions

    if [[ "$HAS_INTEL" == "true" ]]; then
        setup_intel
    fi

    if [[ "$HAS_AMD" == "true" ]]; then
        setup_amd
    fi

    if [[ "$HAS_NVIDIA" == "true" ]]; then
        setup_nvidia
    fi

    echo ""
    echo -e "${GREEN}Hardware acceleration setup finished.${NC}"
}

main "$@"
