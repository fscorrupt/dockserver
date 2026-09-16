#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Automated Storage Cleanup                      #
# Cleans temporary downloads and NZBs when disk usage is high #
###############################################################
set -e

cleannzb="/mnt/nzb"
cleandownload="/mnt/downloads/nzb"

df -H | grep -vE '^Filesystem|tmpfs|cdrom|overlay|udev|/dev/md1|/dev/md127|/dev/md2|mergerfs|remote' | awk '{ print $5 " " $1 }' | while read -r output; do
    usep=$(echo "$output" | awk '{ print $1}' | cut -d'%' -f1)
    partition=$(echo "$output" | awk '{ print $2 }')

    if [[ -n "$usep" && "$usep" =~ ^[0-9]+$ && $usep -ge 80 ]]; then
        echo "High disk usage on $partition (${usep}%). Running automated cleanup..."
        if [[ -d "$cleandownload" ]]; then
            find "$cleandownload" -mindepth 1 -type d -mmin +240 -exec rm -rf {} + 2>/dev/null || true
        fi
        if [[ -d "$cleannzb" ]]; then
            find "$cleannzb" -mindepth 1 -type f -mmin +10080 -exec rm -f {} + 2>/dev/null || true
        fi
    fi
done
