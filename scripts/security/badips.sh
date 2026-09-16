#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Malicious IP Blocklist via IPSet               #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################
set -e

if [[ $EUID -ne 0 ]]; then
    sudo "$0" "$@"
    exit $?
fi

if ! command -v ipset >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -yqq && apt-get install -yqq ipset iptables 2>/dev/null || true
fi

echo "Updating malicious IP blocklist..."
ipset -q flush ips 2>/dev/null || true
ipset -q create ips hash:net 2>/dev/null || true

# Fetch top malicious IP blocklist
iplist=$(curl --compressed -sSL --max-time 15 https://raw.githubusercontent.com/scriptzteam/IP-BlockList-v4/master/ips.txt 2>/dev/null || true)

if [[ -n "$iplist" ]]; then
    echo "$iplist" | grep -v "#" | grep -v -E '[[:space:]][1-2]$' | cut -f 1 | head -n 5000 | while read -r ip; do
        if [[ -n "$ip" ]]; then
            ipset add ips "$ip" 2>/dev/null || true
        fi
    done
fi

iptables -C INPUT -m set --match-set ips src -j DROP 2>/dev/null || iptables -I INPUT -m set --match-set ips src -j DROP 2>/dev/null || true
echo "IPSet blocklist updated successfully."
