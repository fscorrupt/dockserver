#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Automated Migration Tool                        #
# Upgrades legacy DockServer to Traefik v3 + CrowdSec Stack   #
###############################################################
set -e

basefolder="/opt/appdata"
dockserver="/opt/dockserver"
env_file="$basefolder/compose/.env"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

if [[ $EUID -ne 0 ]]; then
    sudo "$0" "$@"
    exit $?
fi

# Detect Docker Compose CLI v2
get_compose_cmd() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}
DOCKER_COMPOSE=$(get_compose_cmd)

echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}    🚀  DockServer Stack Migration & Upgrade Tool                         ${NC}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "This tool safely upgrades your existing DockServer installation to:"
echo "  • Traefik v3 with HTTP/3 & Cloudflare real-client IP tracking"
echo "  • CrowdSec Intrusion Prevention System with Traefik Bouncer Plugin"
echo "  • CrowdSec Automated Threat Feed Blocklist Importer (28+ feeds)"
echo "  • Traefik Log Dashboard & Realtime Metrics Agent"
echo "  • Modern Docker Compose v2 Integration"
echo ""
echo -e "${YELLOW}Your existing SSL certificates (acme.json) and Authelia users/2FA will be preserved.${NC}"
echo ""
read -erp "Proceed with migration? (y/N): " confirm </dev/tty
if [[ ! "$confirm" =~ ^[yY]$ ]]; then
    echo "Migration aborted."
    exit 0
fi

# Step 1: Pre-migration safety backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$basefolder/backup_pre_migration_$TIMESTAMP"
echo ""
echo -e "${BLUE}==> Creating safety backup in $BACKUP_DIR...${NC}"
mkdir -p "$BACKUP_DIR"

if [[ -f "$env_file" ]]; then
    cp -p "$env_file" "$BACKUP_DIR/.env"
fi
if [[ -d "$basefolder/traefik" ]]; then
    cp -rp "$basefolder/traefik" "$BACKUP_DIR/traefik"
fi
if [[ -d "$basefolder/authelia" ]]; then
    cp -rp "$basefolder/authelia" "$BACKUP_DIR/authelia"
fi
echo -e "${GREEN}Safety backup completed successfully.${NC}"

# Step 2: Ensure modern Docker Compose v2 is installed
echo ""
echo -e "${BLUE}==> Checking Docker Engine and Compose v2...${NC}"
if ! docker compose version >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing Docker Compose v2 plugin...${NC}"
    apt-get update -yqq
    apt-get install -yqq docker-compose-plugin || true
fi

# Step 3: Stop legacy edge containers
echo ""
echo -e "${BLUE}==> Stopping legacy edge proxy containers...${NC}"
docker stop traefik authelia cf-companion >/dev/null 2>&1 || true
docker rm traefik authelia cf-companion >/dev/null 2>&1 || true

# Step 4: Preserve existing ACME certs and Authelia DB
echo -e "${BLUE}==> Preserving SSL certificates and credentials...${NC}"
mkdir -p "$basefolder/traefik"/{acme,rules,logs,certs}
mkdir -p "$basefolder/crowdsec"/{config/postoverflows/s01-whitelist,data}
mkdir -p "$basefolder/traefik-dashboard"/{data,positions}

# Check for legacy acme.json location
if [[ -f "$BACKUP_DIR/traefik/acme.json" && ! -s "$basefolder/traefik/acme/acme.json" ]]; then
    cp -p "$BACKUP_DIR/traefik/acme.json" "$basefolder/traefik/acme/acme.json"
fi
chmod 600 "$basefolder/traefik/acme/acme.json" 2>/dev/null || true

# Step 5: Copy new templates
echo -e "${BLUE}==> Deploying modernized Traefik + CrowdSec templates...${NC}"
cp -f "$dockserver/traefik/templates/compose/docker-compose.yml" "$basefolder/compose/docker-compose.yml"
cp -rf "$dockserver/traefik/templates/traefik/rules/"* "$basefolder/traefik/rules/"
cp -f "$dockserver/traefik/templates/crowdsec/acquis.yaml" "$basefolder/crowdsec/config/acquis.yaml"
cp -rf "$dockserver/traefik/templates/crowdsec/postoverflows" "$basefolder/crowdsec/config/"

# Ensure Authelia assets exist
if [[ -d "$dockserver/traefik/templates/authelia/assets" ]]; then
    mkdir -p "$basefolder/authelia/assets"
    cp -rf "$dockserver/traefik/templates/authelia/assets/"* "$basefolder/authelia/assets/" 2>/dev/null || true
fi

# Step 6: Sync .env
echo -e "${BLUE}==> Updating environment variables...${NC}"
bash "$dockserver/apps/.subactions/envmigrate.sh"
# shellcheck disable=SC1090
source "$env_file"

# Generate new tokens if missing
if [[ -z "$TRAEFIK_DASHBOARD_AUTH_TOKEN" ]]; then
    TRAEFIK_DASHBOARD_AUTH_TOKEN=$(openssl rand -hex 32)
    sed -i "/^TRAEFIK_DASHBOARD_AUTH_TOKEN=/d" "$env_file" 2>/dev/null || true
    echo "TRAEFIK_DASHBOARD_AUTH_TOKEN=$TRAEFIK_DASHBOARD_AUTH_TOKEN" >> "$env_file"
fi
if [[ -z "$CROWDSEC_BLOCKLIST_MACHINE_PASSWORD" ]]; then
    CROWDSEC_BLOCKLIST_MACHINE_PASSWORD=$(openssl rand -hex 16)
    sed -i "/^CROWDSEC_BLOCKLIST_MACHINE_PASSWORD=/d" "$env_file" 2>/dev/null || true
    echo "CROWDSEC_BLOCKLIST_MACHINE_PASSWORD=$CROWDSEC_BLOCKLIST_MACHINE_PASSWORD" >> "$env_file"
fi

# Step 7: Bootstrap CrowdSec and generate keys
echo -e "${BLUE}==> Bootstrapping CrowdSec IPS...${NC}"

# Detect server external IP and automatically update static-whitelist.yaml
echo -e "${BLUE}Detecting server external IP for automated CrowdSec whitelisting...${NC}"
server_ext_ip=$(curl -sSL --max-time 5 https://api.ipify.org 2>/dev/null || curl -sSL --max-time 5 https://ifconfig.me 2>/dev/null || curl -sSL --max-time 5 https://icanhazip.com 2>/dev/null || true)
server_ext_ip=$(echo "$server_ext_ip" | tr -d '[:space:]')

whitelist_file="$basefolder/crowdsec/config/postoverflows/s01-whitelist/static-whitelist.yaml"
if [[ -f "$whitelist_file" ]]; then
    if [[ -n "$server_ext_ip" && "$server_ext_ip" =~ ^[0-9a-fA-F.:]+$ ]]; then
        echo -e "${GREEN}Whitelisting server external IP: ${server_ext_ip}${NC}"
        if grep -q "SERVER_IP_PLACEHOLDER" "$whitelist_file"; then
            sed -i "s/SERVER_IP_PLACEHOLDER/$server_ext_ip/g" "$whitelist_file"
        elif ! grep -q "$server_ext_ip" "$whitelist_file"; then
            sed -i "/^  ip:/a \    - \"$server_ext_ip\"" "$whitelist_file"
        fi
        sed -i "/^SERVERIP=/d" "$env_file" 2>/dev/null || true
        echo "SERVERIP=$server_ext_ip" >> "$env_file"
    else
        sed -i "/SERVER_IP_PLACEHOLDER/d" "$whitelist_file" 2>/dev/null || true
    fi
fi

# Update ddns-whitelist.yaml with current domain if configured
ddns_whitelist="$basefolder/crowdsec/config/postoverflows/s01-whitelist/ddns-whitelist.yaml"
if [[ -f "$ddns_whitelist" && -n "$DOMAIN" && "$DOMAIN" != "example.com" ]]; then
    sed -i "s/vpn\.example\.com/vpn.$DOMAIN/g" "$ddns_whitelist" 2>/dev/null || true
fi

cd "$basefolder/compose"
$DOCKER_COMPOSE up -d crowdsec

echo "Waiting for CrowdSec LAPI..."
for i in {1..20}; do
    if docker exec crowdsec cscli version >/dev/null 2>&1; then break; fi
    sleep 1
done

# Register Traefik bouncer
echo "Generating Traefik Bouncer API key..."
docker exec crowdsec cscli bouncers delete traefik-bouncer >/dev/null 2>&1 || true
CROWDSEC_BOUNCER_KEY=$(docker exec crowdsec cscli bouncers add traefik-bouncer -o raw 2>/dev/null | tr -d '\r\n' || true)
sed -i "/^CROWDSEC_BOUNCER_KEY=/d" "$env_file" 2>/dev/null || true
echo "CROWDSEC_BOUNCER_KEY=$CROWDSEC_BOUNCER_KEY" >> "$env_file"

# Register Blocklist Import
echo "Registering Threat Intelligence feeds..."
docker exec crowdsec cscli bouncers delete blocklist-import >/dev/null 2>&1 || true
CROWDSEC_BLOCKLIST_BOUNCER_KEY=$(docker exec crowdsec cscli bouncers add blocklist-import -o raw 2>/dev/null | tr -d '\r\n' || true)
sed -i "/^CROWDSEC_BLOCKLIST_BOUNCER_KEY=/d" "$env_file" 2>/dev/null || true
echo "CROWDSEC_BLOCKLIST_BOUNCER_KEY=$CROWDSEC_BLOCKLIST_BOUNCER_KEY" >> "$env_file"

docker exec crowdsec cscli machines delete "${CROWDSEC_BLOCKLIST_MACHINE_ID:-blocklist-import}" >/dev/null 2>&1 || true
docker exec crowdsec cscli machines add "${CROWDSEC_BLOCKLIST_MACHINE_ID:-blocklist-import}" --password "${CROWDSEC_BLOCKLIST_MACHINE_PASSWORD}" -f - >/dev/null 2>&1 || true

# Update middlewares.toml
MW_TOML="$basefolder/traefik/rules/middlewares.toml"
sed -i "s#example.com#$DOMAIN#g" "$MW_TOML"
sed -i "s#https:$DOMAIN#https://$DOMAIN#g" "$MW_TOML"
sed -i "s/CROWDSEC_BOUNCER_KEY_ID/$CROWDSEC_BOUNCER_KEY/g" "$MW_TOML"
sed -i "s/crowdsecLapiKey = \".*\"/crowdsecLapiKey = \"$CROWDSEC_BOUNCER_KEY\"/g" "$MW_TOML"

# Step 8: Launch all upgraded edge services
echo -e "${BLUE}==> Pulling and starting upgraded Edge Gateway...${NC}"
$DOCKER_COMPOSE pull
$DOCKER_COMPOSE up -d --remove-orphans

echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}    🚀  Migration to Traefik v3 + CrowdSec Stack Succeeded!               ${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Traefik Proxy:       ${CYAN}https://traefik.${DOMAIN}${NC}"
echo -e "  Authelia SSO / MFA:  ${CYAN}https://authelia.${DOMAIN}${NC}"
echo -e "  Traefik Dashboard:   ${CYAN}https://traefik-dashboard.${DOMAIN}${NC}"
echo ""
echo -e "  Your previous configuration was safely preserved in:"
echo -e "  ${YELLOW}$BACKUP_DIR${NC}"
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
