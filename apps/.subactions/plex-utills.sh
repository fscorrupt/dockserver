#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Plex-Utills Configuration Helper               #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################
set -e

basefolder="/opt/appdata"
env_file="$basefolder/compose/.env"

if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
fi

plex_running=$(docker ps -a --format '{{.Names}}' | grep -xq 'plex' && echo true || echo false)

if [[ -d "/opt/appdata/plex/" && "$plex_running" == "true" ]]; then
    if [[ -z "$SERVERIP" || "$SERVERIP" == "SERVERIP_ID" ]]; then
        SERVERIP=$(curl -sSL --max-time 5 https://api.ipify.org 2>/dev/null || curl -sSL --max-time 5 https://ifconfig.me 2>/dev/null || echo "127.0.0.1")
        SERVERIP=$(echo "$SERVERIP" | tr -d '[:space:]')
    fi

    token=""
    pref_file="/opt/appdata/plex/database/Library/Application Support/Plex Media Server/Preferences.xml"
    if [[ -f "$pref_file" ]]; then
        token=$(grep -Po '(?<=PlexOnlineToken=")[^"]*' "$pref_file" | tail -1 || true)
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "    🚀  Plex-Utills Quick Setup Info"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Navigate to Config Page: https://plex-utills.${DOMAIN:-example.com}/config"
    echo ""
    echo "  Plex Connection Details:"
    echo "  • Plex URL:   http://${SERVERIP}:32400"
    echo "  • Plex Token: ${token:-<Enter your token from Plex Settings>}"
    echo ""
    echo "  Save your configuration in the Web UI to activate automated posters/banners."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -erp "Press [ENTER] to continue: " _ </dev/tty
fi
