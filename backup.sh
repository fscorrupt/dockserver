#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Automated Backup Dispatcher                    #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################
set -e

DESTINATION="/mnt/downloads/appbackups/local"
mkdir -p "$DESTINATION"

# Filter out infrastructure services
dockers=$(docker ps --format '{{.Names}}' | grep -vE '^(traefik.*|authelia|cf-companion|crowdsec.*|dockupdater|dockserver)$' || true)

if [[ -z "$dockers" ]]; then
    echo "No application containers running to back up."
    exit 0
fi

docker pull -q ghcr.io/dockserver/docker-backup:latest || true

for app in ${dockers}; do
    echo "Backing up ${app}..."
    docker run --rm \
        -v /opt/appdata:/backup/"$app" \
        -v /mnt:/mnt \
        ghcr.io/dockserver/docker-backup:latest backup "$app" local 2>/dev/null || true

    if [[ -f "$DESTINATION/${app}.tar.gz" ]]; then
        chown 1000:1000 "$DESTINATION/${app}.tar.gz" 2>/dev/null || true
    fi
done

echo "DockServer backup completed."
