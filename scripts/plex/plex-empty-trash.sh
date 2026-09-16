#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Plex Media Server Empty Trash Tool             #
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

# Extract section IDs cleanly without -it (safe for cron)
mapfile -t section_ids < <(docker exec plex /usr/lib/plexmediaserver/Plex\ Media\ Scanner --list 2>/dev/null | awk '{print $1}' | sed 's/://g' | grep -E '^[0-9]+$' || true)

for id in "${section_ids[@]}"; do
    echo "Emptying trash for Plex library section $id..."
    curl -fsS -X PUT -H "X-Plex-Token: $X_PLEX_TOKEN" "http://localhost:32400/library/sections/$id/emptyTrash" >/dev/null 2>&1 || true
done

echo "Plex empty trash complete."
