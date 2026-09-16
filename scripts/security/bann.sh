#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Host Security Hardening (Fail2ban & Bad IPs)   #
###############################################################
set -e

if [[ $EUID -ne 0 ]]; then
    sudo "$0" "$@"
    exit $?
fi

# Run badips blocklist
if [[ -f "/opt/dockserver/scripts/security/badips.sh" ]]; then
    bash "/opt/dockserver/scripts/security/badips.sh" || true
fi

# Fail2ban filters setup
if command -v fail2ban-client >/dev/null 2>&1; then
    mkdir -p /etc/fail2ban/filter.d /etc/fail2ban/jail.d

    cat << 'EOF' > /etc/fail2ban/filter.d/log4j-jndi.conf
[log4j-jndi]
maxretry = 1
enabled = true
port = 80,443
logpath = /opt/appdata/traefik/logs/traefik.log
EOF

    cat << 'EOF' > /etc/fail2ban/filter.d/authelia.conf
[authelia]
enabled = true
port = http,https,9091
filter = authelia
logpath = /opt/appdata/authelia/authelia.log
maxretry = 3
bantime = 24h
findtime = 1h
chain = DOCKER-USER
EOF

    if systemctl is-active --quiet fail2ban; then
        systemctl reload-or-restart fail2ban 2>/dev/null || true
    fi
fi

echo "Security hardening completed."
