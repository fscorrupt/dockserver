#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Vaultwarden / Bitwarden Setup Helper           #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################
set -e

basefolder="/opt/appdata"
env_file="$basefolder/compose/.env"

if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
fi

mkdir -p "$basefolder/bitwarden"

# Generate admin token and setup .env if not present
if [[ ! -f "$basefolder/bitwarden/.env" ]]; then
    admintoken=$(openssl rand -base64 48)
    cat <<EOF > "$basefolder/bitwarden/.env"
# Vaultwarden environment configuration
ADMIN_TOKEN=${admintoken}
SIGNUPS_ALLOWED=true
WEBSOCKET_ENABLED=true
LOG_FILE=/data/error.log
LOG_LEVEL=info
EOF
    chmod 600 "$basefolder/bitwarden/.env"
    echo "Generated new Vaultwarden admin token."
fi

touch "$basefolder/bitwarden/error.log"
chmod 644 "$basefolder/bitwarden/error.log" 2>/dev/null || true

# Fail2ban configuration if fail2ban is present
if command -v fail2ban-client >/dev/null 2>&1; then
    mkdir -p /etc/fail2ban/filter.d /etc/fail2ban/jail.d

    cat << 'EOF' > /etc/fail2ban/filter.d/bitwardenrs.conf
[INCLUDES]
before = common.conf
[Definition]
failregex = ^.*Username or password is incorrect\. Try again\. IP: <HOST>\. Username:.*$
ignoreregex =
EOF

    cat << 'EOF' > /etc/fail2ban/jail.d/bitwardenrs.local
[bitwardenrs]
enabled = true
port = 80,443,8081
filter = bitwardenrs
logpath = /opt/appdata/bitwarden/error.log
maxretry = 3
bantime = 14400
findtime = 14400
EOF

    cat << 'EOF' > /etc/fail2ban/filter.d/bitwardenrs-admin.conf
[INCLUDES]
before = common.conf
[Definition]
failregex = ^.*Unauthorized Error: Invalid admin token\. IP: <HOST>.*$
ignoreregex =
EOF

    cat << 'EOF' > /etc/fail2ban/jail.d/bitwardenrs-admin.local
[bitwardenrs-admin]
enabled = true
port = 80,443
filter = bitwardenrs-admin
logpath = /opt/appdata/bitwarden/error.log
maxretry = 5
bantime = 14400
findtime = 14400
EOF

    if systemctl is-active --quiet fail2ban; then
        systemctl reload-or-restart fail2ban 2>/dev/null || true
    fi
fi

chown -R 1000:1000 "$basefolder/bitwarden" 2>/dev/null || true
echo "Vaultwarden configuration completed."
