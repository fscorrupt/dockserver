#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Plex Media Server Database Optimizer           #
# Cron-friendly: Non-interactive and reliable                 #
###############################################################
set -e

pref_file="/opt/appdata/plex/database/Library/Application Support/Plex Media Server/Preferences.xml"

if ! docker ps --format '{{.Names}}' | grep -xq 'plex'; then
    echo "Plex container is not currently running."
    exit 0
fi

if [[ ! -f "$pref_file" ]]; then
    echo "Plex Preferences.xml not found."
    exit 0
fi

X_PLEX_TOKEN=$(grep -Po '(?<=PlexOnlineToken=")[^"]*' "$pref_file" | tail -1 || true)
if [[ -z "$X_PLEX_TOKEN" ]]; then
    echo "Could not extract Plex Online Token."
    exit 1
fi

echo "Triggering Plex database optimization..."
curl -fsS -X PUT "http://localhost:32400/library/optimize?async=1&X-Plex-Token=$X_PLEX_TOKEN" >/dev/null 2>&1 || true
echo "Plex database optimization triggered."
