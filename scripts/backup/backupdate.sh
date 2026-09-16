#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Scheduled Daily Application Backup             #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################
set -e

# Settings
FOLDER="/opt/appdata"
DESTINATION="/mnt/downloads/appbackups"
STORAGE="local"
WEBHOOK_URL=""

# Ensure compression tools are installed
if ! command -v pigz >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -yqq && apt-get install -yqq tar pigz pv 2>/dev/null || true
fi

TARGET_DIR="${DESTINATION}/${STORAGE}"
mkdir -p "$TARGET_DIR"

OPTIONSTAR="--warning=no-file-changed \
  --ignore-failed-read \
  --absolute-names \
  --warning=no-file-removed \
  --use-compress-program=pigz"

if [[ -f "/opt/dockserver/apps/.backup/backup_excludes" ]]; then
    OPTIONSTAR="$OPTIONSTAR --exclude-from=/opt/dockserver/apps/.backup/backup_excludes"
fi

dockers=$(docker ps -a --format '{{.Names}}' | grep -vE '^(traefik.*|authelia|cf-companion|crowdsec.*|dockupdater|dockserver)$' || true)

for app in ${dockers}; do
    ARCHIVETAR="${app}.tar.gz"

    if [[ ! -d "${FOLDER}/${app}" ]]; then
        continue
    fi

    echo "Backing up ${app}..."

    # Check if app is in mediaserver or mediamanager categories to temporarily stop for clean SQLite DB backup
    app_file=$(find /opt/dockserver/apps/ -maxdepth 2 -type f -name "${app}.yml" ! -path "*/.subactions/*" 2>/dev/null | head -1 || true)
    section=""
    if [[ -n "$app_file" ]]; then
        section=$(basename "$(dirname "$app_file")")
    fi

    if [[ "$section" == "mediaserver" || "$section" == "mediamanager" ]]; then
        docker stop "${app}" >/dev/null 2>&1 || true
        tar ${OPTIONSTAR} -C "${FOLDER}/${app}" -pcf "${TARGET_DIR}/${ARCHIVETAR}" ./ 2>/dev/null || true
        docker start "${app}" >/dev/null 2>&1 || true
    else
        tar ${OPTIONSTAR} -C "${FOLDER}/${app}" -pcf "${TARGET_DIR}/${ARCHIVETAR}" ./ 2>/dev/null || true
    fi

    chown -hR 1000:1000 "${TARGET_DIR}/${ARCHIVETAR}" 2>/dev/null || true

    if [[ -n "$WEBHOOK_URL" ]]; then
        TIMESTAMP=$(date '+%H:%M:%S')
        curl -fsS -H "Content-Type: application/json" \
            -X POST \
            -d "{\"content\": \"Backup of ${app} completed at ${TIMESTAMP}!\"}" \
            "$WEBHOOK_URL" >/dev/null 2>&1 || true
    fi
done

echo "Daily application backup finished successfully."
