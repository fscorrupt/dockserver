#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Traefik Legacy Active Log Banning Daemon       #
# (CrowdSec IPS is the primary defense engine)                #
###############################################################
set -e

logfile="/opt/appdata/traefik/logs/traefik.log"
if [[ ! -f "$logfile" && -f "/opt/appdata/traefik/traefik.log" ]]; then
    logfile="/opt/appdata/traefik/traefik.log"
fi

banned_file="/opt/appdata/traefik/logs/banned.ips"
mkdir -p "$(dirname "$banned_file")"
touch "$banned_file"

echo "Starting Traefik log monitor daemon..."

while true; do
    if [[ -f "$logfile" ]]; then
        # Check for exploit patterns in recent logs
        tail -n 100 "$logfile" 2>/dev/null | grep -E '/_ignition/execute-solution|/\?x=\$\{jndi:' 2>/dev/null | awk '{print $1}' | while read -r ip; do
            if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                if ! grep -xq "$ip" "$banned_file"; then
                    echo "Dropping malicious exploit IP: $ip"
                    iptables -I INPUT -s "$ip" -j DROP 2>/dev/null || true
                    echo "$ip" >> "$banned_file"
                fi
            fi
        done
    fi
    sleep 10
done
