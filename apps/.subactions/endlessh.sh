#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Endlessh & Host SSH Port Configuration         #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################
set -e

restart_sshd() {
    echo "Applying SSH port change..."
    systemctl daemon-reload 2>/dev/null || true
    systemctl restart ssh.socket 2>/dev/null || true
    systemctl restart ssh.service 2>/dev/null || systemctl restart sshd.service 2>/dev/null || true
}

get_current_port() {
    local p
    p=$(grep -P '^[#\s]*Port\s+\d+' /etc/ssh/sshd_config 2>/dev/null | sed -E 's/.*Port\s+([0-9]+).*/\1/' | head -1 || echo "22")
    echo "${p:-22}"
}

defaultport() {
    local sshport=22
    sed -i -E 's/^[#\s]*Port\s+[0-9]+/Port 22/' /etc/ssh/sshd_config
    restart_sshd
    echo "SSH port reset to default 22."
    sleep 2
}

randomport() {
    local sshport=$((RANDOM % 1833 + 1500))
    sed -i -E "s/^[#\s]*Port\s+[0-9]+/Port $sshport/" /etc/ssh/sshd_config
    restart_sshd
    echo "SSH port changed to random port: $sshport"
    sleep 2
}

customport() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "    🚀  Custom SSH Port"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -erp "Enter custom SSH Port (22-65500): " newport </dev/tty
    if [[ -n "$newport" && "$newport" =~ ^[0-9]+$ && "$newport" -ge 22 && "$newport" -le 65500 ]]; then
        sed -i -E "s/^[#\s]*Port\s+[0-9]+/Port $newport/" /etc/ssh/sshd_config
        restart_sshd
        echo "SSH port changed to: $newport"
        sleep 2
    else
        echo "Invalid port. Must be a number between 22 and 65500."
        sleep 2
    fi
}

main() {
    # Ensure Port directive exists in /etc/ssh/sshd_config
    if ! grep -qE '^[#\s]*Port' /etc/ssh/sshd_config 2>/dev/null; then
        echo "Port 22" >> /etc/ssh/sshd_config
    fi

    local current_port
    current_port=$(get_current_port)

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "    🚀  DockServer - SSH Port Management"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Current Active SSH Port: $current_port"
    echo ""
    echo "  [ 1 ] Reset to default Port 22"
    echo "  [ 2 ] Generate random SSH Port"
    echo "  [ 3 ] Specify custom SSH Port"
    echo "  [ Z ] Keep current and exit"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -erp "Select Option: " choice </dev/tty

    case $choice in
        1) defaultport ;;
        2) randomport ;;
        3) customport ;;
        *) return 0 ;;
    esac
}

main "$@"
