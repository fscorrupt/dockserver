#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Dashy Setup Helper                             #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################
set -e

FOLDER="/opt/appdata"
CONF="${FOLDER}/dashy/conf.yml"
appfolder="/opt/dockserver/apps"
FILE=".subactions/dashy.j2"

mkdir -p "${FOLDER}/dashy"

if [[ ! -f "$CONF" && -f "$appfolder/$FILE" ]]; then
    cp -f "$appfolder/$FILE" "$CONF"
fi

chown -R 1000:1000 "$FOLDER/dashy" 2>/dev/null || true
