#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Main Dispatcher Interface                      #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################
set -e

basefolder="/opt/appdata"
env_file="$basefolder/compose/.env"
dockserver="/opt/dockserver"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

sync_env() {
    if [[ -f "$dockserver/apps/.subactions/envmigrate.sh" ]]; then
        bash "$dockserver/apps/.subactions/envmigrate.sh"
    fi
    if [[ -f "$env_file" ]]; then
        # shellcheck disable=SC1090
        source "$env_file"
    fi
}

updatebin() {
    local file="/opt/dockserver/.installer/dockserver"
    if [[ -f "$file" ]]; then
        cp -f "$file" /usr/bin/dockserver 2>/dev/null || true
        cp -f "$file" /bin/dockserver 2>/dev/null || true
        chmod +x /usr/bin/dockserver /bin/dockserver 2>/dev/null || true
    fi
}

get_status() {
    local service="$1"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qE "^${service}$"; then
        echo -e "${GREEN}Running${NC}"
    elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qE "^${service}$"; then
        echo -e "${YELLOW}Stopped${NC}"
    else
        echo -e "${RED}Not Installed${NC}"
    fi
}

toggle_servermode() {
    sync_env
    local current="${SERVER_MODE:-local}"
    local new_mode="cloud"
    if [[ "$current" == "cloud" ]]; then
        new_mode="local"
    fi
    sed -i "/^SERVER_MODE=/d" "$env_file" 2>/dev/null || true
    echo "SERVER_MODE=$new_mode" >> "$env_file"
    sync_env
    echo -e "${GREEN}Server mode switched to: ${BOLD}${new_mode}${NC}"
    sleep 1
}

system_maintenance() {
    clear
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}    🚀  System & Docker Maintenance                                       ${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  [ 1 ] Prune Unused Docker Images & Containers"
    echo "  [ 2 ] Run Disk Space Cleanup (Download caches)"
    echo "  [ 3 ] View Edge Gateway Logs"
    echo "  [ Z ] Back"
    echo ""
    read -erp "Select Option: " opt </dev/tty
    case $opt in
        1)
            docker system prune -af --volumes || true
            echo -e "${GREEN}Docker pruned successfully.${NC}"
            sleep 2
            ;;
        2)
            if [[ -f "$dockserver/scripts/disk_cleanup.sh" ]]; then
                bash "$dockserver/scripts/disk_cleanup.sh"
            fi
            sleep 2
            ;;
        3)
            docker compose -f "$basefolder/compose/docker-compose.yml" logs --tail=100 -f || true
            ;;
        *) ;;
    esac
}

ensure_preinstalled() {
    if [[ ! -f "$basefolder/.preinstalled" && -f "$dockserver/preinstall/install.sh" ]]; then
        clear
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}    🚀  DockServer First-Run: Host Pre-Installation & Optimization       ${NC}"
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "DockServer will now automatically configure system dependencies, kernel BBR,"
        echo "storage directories, fail2ban security, and GPU hardware acceleration."
        echo ""
        cd "$dockserver/preinstall" && bash install.sh
        echo ""
        read -erp "Host optimization completed! Press [ENTER] to launch the control panel: " _ </dev/tty
    fi
}

headinterface() {
    updatebin
    ensure_preinstalled
    while true; do
        sync_env
        clear

        local docker_status
        if docker info >/dev/null 2>&1; then
            docker_status="${GREEN}Active${NC}"
        else
            if [[ -f "$dockserver/scripts/docker/ensure_docker.sh" ]]; then
                bash "$dockserver/scripts/docker/ensure_docker.sh" >/dev/null 2>&1 || true
            else
                systemctl unmask docker.service docker.socket containerd 2>/dev/null || true
                systemctl daemon-reload 2>/dev/null || true
                systemctl enable --now containerd docker.socket docker.service 2>/dev/null || true
                systemctl restart docker.service 2>/dev/null || systemctl start docker.service 2>/dev/null || true
            fi
            if docker info >/dev/null 2>&1; then
                docker_status="${GREEN}Active${NC}"
            else
                docker_status="${RED}Inactive (Failed to start)${NC}"
            fi
        fi

        local preinstall_label
        if [[ -f "$basefolder/.preinstalled" ]]; then
            local gpu_type
            gpu_type=$(grep '^GPU=' "$basefolder/.preinstalled" 2>/dev/null | cut -d= -f2 || true)
            if [[ -n "$gpu_type" && "$gpu_type" != "None" ]]; then
                preinstall_label="${GREEN}Completed (${gpu_type})${NC}"
            else
                preinstall_label="${GREEN}Completed${NC}"
            fi
        else
            preinstall_label="${YELLOW}Pending (Recommended)${NC}"
        fi

        local traefik_status
        traefik_status=$(get_status "traefik")
        local crowdsec_status
        crowdsec_status=$(get_status "crowdsec")
        local authelia_status
        authelia_status=$(get_status "authelia")

        local pre_tag=""
        if [[ -f "$basefolder/.preinstalled" ]]; then
            pre_tag=" ${GREEN}[Completed]${NC}"
        fi

        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}    🚀  DockServer - Unified Orchestration Platform                       ${NC}"
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  Domain:             ${CYAN}${DOMAIN:-example.com}${NC}"
        echo -e "  Server Environment: ${YELLOW}${SERVER_MODE:-local}${NC}"
        echo -e "  Docker Engine:      $docker_status"
        echo -e "  Host Pre-Install:   $preinstall_label"
        echo -e "  Traefik Proxy:      $traefik_status"
        echo -e "  CrowdSec IPS:       $crowdsec_status"
        echo -e "  Authelia Gateway:   $authelia_status"
        echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}[ 1 ] Edge Gateway (Traefik v3 + CrowdSec + Authelia)${NC}"
        echo -e "  ${BOLD}[ 2 ] Applications Catalog (Install / Remove / Backup)${NC}"
        echo -e "  ${BOLD}[ 3 ] Host Pre-Installation & Optimization${pre_tag}"
        echo -e "  ${BOLD}[ 4 ] Migration Tool (Upgrade from Legacy DockServer)${NC}"
        echo -e "  ${BOLD}[ 5 ] Toggle Server Mode [Cloud <-> Local]${NC}"
        echo -e "  ${BOLD}[ 6 ] System & Docker Maintenance${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}[ Z / Exit ] - Exit${NC}"
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        read -erp "Select Option and Press [ENTER]: " headsection </dev/tty

        case $headsection in
            1)
                if [[ ! -f "$basefolder/.preinstalled" && -f "$dockserver/preinstall/install.sh" ]]; then
                    cd "$dockserver/preinstall" && bash install.sh
                fi
                if [[ -f "$dockserver/scripts/docker/ensure_docker.sh" ]]; then
                    bash "$dockserver/scripts/docker/ensure_docker.sh"
                fi
                cd "$dockserver/traefik" && bash install.sh
                ;;
            2)
                if [[ ! -f "$basefolder/.preinstalled" && -f "$dockserver/preinstall/install.sh" ]]; then
                    cd "$dockserver/preinstall" && bash install.sh
                fi
                if [[ -f "$dockserver/scripts/docker/ensure_docker.sh" ]]; then
                    bash "$dockserver/scripts/docker/ensure_docker.sh"
                fi
                cd "$dockserver/apps" && bash install.sh
                ;;
            3)
                cd "$dockserver/preinstall" && bash install.sh
                read -erp "Press [ENTER] to continue..." _ </dev/tty
                ;;
            4)
                if [[ -f "$dockserver/scripts/migrate.sh" ]]; then
                    bash "$dockserver/scripts/migrate.sh"
                fi
                read -erp "Press [ENTER] to continue..." _ </dev/tty
                ;;
            5)
                toggle_servermode
                ;;
            6)
                system_maintenance
                ;;
            z|Z|exit|EXIT|close)
                exit 0
                ;;
            *) ;;
        esac
    done
}

headinterface
