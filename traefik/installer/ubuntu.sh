#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Traefik v3, CrowdSec IPS & Authelia Installer   #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################
set -e

basefolder="/opt/appdata"
appfolder="/opt/dockserver"
source_tpl="/opt/dockserver/traefik/templates"
compose_file="$basefolder/compose/docker-compose.yml"
env_file="$basefolder/compose/.env"

# Colors for modern TUI
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
    sudo "$0" "$@"
    exit $?
fi

# Ensure docker compose command is available
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

# Helper: Ensure Docker daemon is active and responsive
ensure_docker() {
    if [[ -f "/opt/dockserver/scripts/docker/ensure_docker.sh" ]]; then
        bash "/opt/dockserver/scripts/docker/ensure_docker.sh"
        return $?
    fi

    if docker info >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${YELLOW}Docker daemon is not running. Attempting to start docker.service...${NC}"
    systemctl unmask docker.service docker.socket containerd 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable --now containerd docker.socket docker.service 2>/dev/null || true
    systemctl restart docker.service 2>/dev/null || systemctl start docker.service 2>/dev/null || true

    local attempts=15
    while [[ $attempts -gt 0 ]]; do
        if docker info >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        attempts=$((attempts - 1))
    done

    echo -e "${RED}Error: Cannot connect to Docker daemon at unix:///var/run/docker.sock.${NC}"
    read -erp "Press [ENTER] to return to menu..." _ </dev/tty
    return 1
}

# Helper: Run env migrate
sync_env() {
    if [[ -f "$appfolder/apps/.subactions/envmigrate.sh" ]]; then
        bash "$appfolder/apps/.subactions/envmigrate.sh"
    fi
    if [[ -f "$env_file" ]]; then
        # shellcheck disable=SC1090
        source "$env_file"
    fi
}

init_directories() {
    mkdir -p "$basefolder/compose"
    mkdir -p "$basefolder/traefik"/{rules,certs,acme,logs}
    mkdir -p "$basefolder/crowdsec"/{config/postoverflows/s01-whitelist,data}
    mkdir -p "$basefolder/traefik-dashboard"/{data,positions}
    mkdir -p "$basefolder/authelia"/assets

    # Migrate legacy acme.json if present
    if [[ -f "$basefolder/traefik/acme.json" && ( ! -f "$basefolder/traefik/acme/acme.json" || ! -s "$basefolder/traefik/acme/acme.json" ) ]]; then
        cp -p "$basefolder/traefik/acme.json" "$basefolder/traefik/acme/acme.json"
    fi

    touch "$basefolder/traefik/acme/acme.json"
    touch "$basefolder/traefik/logs/traefik.log"
    touch "$basefolder/traefik/logs/access.log"
    touch "$basefolder/authelia/authelia.log"

    chmod 600 "$basefolder/traefik/acme/acme.json"
    chmod 644 "$basefolder/traefik/logs/"*.log || true
    chmod 644 "$basefolder/authelia/authelia.log" || true
    chown -R 1000:1000 "$basefolder/authelia" "$basefolder/crowdsec" "$basefolder/traefik-dashboard" || true

    # Ensure external Docker proxy network exists
    local net_name="${DOCKERNETWORK:-proxy}"
    if ! docker network inspect "$net_name" >/dev/null 2>&1; then
        echo -e "${BLUE}Creating external Docker network '${net_name}'...${NC}"
        docker network create --driver=bridge "$net_name" 2>/dev/null || true
    fi
}

copy_templates() {
    init_directories

    # 1. Compose file
    if [[ -f "$source_tpl/compose/docker-compose.yml" ]]; then
        cp -f "$source_tpl/compose/docker-compose.yml" "$compose_file"
    fi

    # 2. Traefik rules
    if [[ -d "$source_tpl/traefik/rules" ]]; then
        cp -rf "$source_tpl/traefik/rules/"* "$basefolder/traefik/rules/"
    fi

    # 3. CrowdSec configuration
    if [[ -f "$source_tpl/crowdsec/acquis.yaml" ]]; then
        cp -f "$source_tpl/crowdsec/acquis.yaml" "$basefolder/crowdsec/config/acquis.yaml"
    fi
    if [[ -d "$source_tpl/crowdsec/postoverflows" ]]; then
        cp -rf "$source_tpl/crowdsec/postoverflows" "$basefolder/crowdsec/config/"
    fi

    # 4. Authelia configuration (only copy if not already customized)
    if [[ ! -f "$basefolder/authelia/configuration.yml" && -f "$source_tpl/authelia/configuration.yml" ]]; then
        cp -f "$source_tpl/authelia/configuration.yml" "$basefolder/authelia/configuration.yml"
    fi
    if [[ ! -f "$basefolder/authelia/users_database.yml" && -f "$source_tpl/authelia/users_database.yml" ]]; then
        cp -f "$source_tpl/authelia/users_database.yml" "$basefolder/authelia/users_database.yml"
    fi
    if [[ -d "$source_tpl/authelia/assets" ]]; then
        cp -rf "$source_tpl/authelia/assets/"* "$basefolder/authelia/assets/" 2>/dev/null || true
    fi
}

prompt_domain() {
    echo ""
    echo -e "${CYAN}${BOLD}==> Domain Configuration${NC}"
    echo "Enter the root domain managed on Cloudflare (e.g., example.com):"
    read -erp "Domain [${DOMAIN:-example.com}]: " input_domain </dev/tty
    DOMAIN="${input_domain:-${DOMAIN:-example.com}}"

    # Save to .env
    sed -i "/^DOMAIN=/d" "$env_file" 2>/dev/null || true
    echo "DOMAIN=$DOMAIN" >> "$env_file"
    sync_env
}

prompt_displayname() {
    echo ""
    echo -e "${CYAN}${BOLD}==> Authelia Admin Username${NC}"
    read -erp "Enter Authelia admin username [${AUTHELIA_USER:-admin}]: " input_user </dev/tty
    AUTHELIA_USER="${input_user:-${AUTHELIA_USER:-admin}}"

    sed -i "/^AUTHELIA_USER=/d" "$env_file" 2>/dev/null || true
    echo "AUTHELIA_USER=$AUTHELIA_USER" >> "$env_file"
    sync_env
}

prompt_password() {
    echo ""
    echo -e "${CYAN}${BOLD}==> Authelia Admin Password${NC}"
    read -s -erp "Enter Authelia admin password: " input_pass </dev/tty
    echo ""
    if [[ -n "$input_pass" ]]; then
        ensure_docker || return 1
        echo -e "${BLUE}Generating secure Argon2id password hash...${NC}"
        # Pull authelia image if needed to generate hash
        docker pull -q docker.io/authelia/authelia:latest >/dev/null 2>&1 || true
        AUTHELIA_HASH=$(docker run --rm docker.io/authelia/authelia:latest authelia crypto hash-password "$input_pass" 2>/dev/null | grep -E '^\$argon2id' || true)
        if [[ -z "$AUTHELIA_HASH" ]]; then
            AUTHELIA_HASH=$(docker run --rm docker.io/authelia/authelia:latest authelia crypto hash generate argon2 --password "$input_pass" 2>/dev/null | sed 's/Digest: //g' || true)
        fi

        if [[ -n "$AUTHELIA_HASH" ]]; then
            # Update users_database.yml
            cat > "$basefolder/authelia/users_database.yml" <<EOF
###############################################################
#             Authelia Users Database                         #
###############################################################
users:
  ${AUTHELIA_USER:-admin}:
    displayname: "${AUTHELIA_USER:-admin}"
    password: "${AUTHELIA_HASH}"
    email: "${CLOUDFLARE_EMAIL:-admin@${DOMAIN:-example.com}}"
    groups:
      - admins
      - dev
EOF
            chmod 644 "$basefolder/authelia/users_database.yml"
            chown 1000:1000 "$basefolder/authelia/users_database.yml"
            echo -e "${GREEN}Authelia user '${AUTHELIA_USER:-admin}' configured successfully!${NC}"
        else
            echo -e "${RED}Failed to generate password hash. Please verify Docker is running.${NC}"
        fi
    fi
}

prompt_cfemail() {
    echo ""
    echo -e "${CYAN}${BOLD}==> Cloudflare Account Email${NC}"
    read -erp "Email [${CLOUDFLARE_EMAIL:-user@example.com}]: " input_email </dev/tty
    CLOUDFLARE_EMAIL="${input_email:-${CLOUDFLARE_EMAIL:-user@example.com}}"

    sed -i "/^CLOUDFLARE_EMAIL=/d" "$env_file" 2>/dev/null || true
    echo "CLOUDFLARE_EMAIL=$CLOUDFLARE_EMAIL" >> "$env_file"
    sync_env
}

prompt_cfkey() {
    echo ""
    echo -e "${CYAN}${BOLD}==> Cloudflare Global API Key${NC}"
    echo "Find this in Cloudflare Dashboard -> My Profile -> API Tokens -> Global API Key"
    read -erp "Global API Key [${CLOUDFLARE_API_KEY}]: " input_key </dev/tty
    CLOUDFLARE_API_KEY="${input_key:-${CLOUDFLARE_API_KEY}}"

    sed -i "/^CLOUDFLARE_API_KEY=/d" "$env_file" 2>/dev/null || true
    echo "CLOUDFLARE_API_KEY=$CLOUDFLARE_API_KEY" >> "$env_file"
    sync_env
}

prompt_cfzoneid() {
    echo ""
    echo -e "${CYAN}${BOLD}==> Cloudflare Zone ID${NC}"
    echo "Find this in Cloudflare Dashboard -> Click Domain -> Overview (right sidebar)"
    read -erp "Zone ID [${DOMAIN1_ZONE_ID}]: " input_zone </dev/tty
    DOMAIN1_ZONE_ID="${input_zone:-${DOMAIN1_ZONE_ID}}"

    sed -i "/^DOMAIN1_ZONE_ID=/d" "$env_file" 2>/dev/null || true
    echo "DOMAIN1_ZONE_ID=$DOMAIN1_ZONE_ID" >> "$env_file"
    sync_env
}

prompt_servermode() {
    echo ""
    echo -e "${CYAN}${BOLD}==> Server Environment Mode${NC}"
    echo "Select where this DockServer is hosted:"
    echo "  [ 1 ] Local Server (Home Lab / Bare-metal LAN - disables cloud mount & uploader) [DEFAULT]"
    echo "  [ 2 ] Cloud Server (VPS / Dedicated e.g. Hetzner, Vultr, Netcup)"
    read -erp "Choice [1/2] (Current: ${SERVER_MODE:-local}): " mode_choice </dev/tty
    case $mode_choice in
        2|cloud|Cloud|CLOUD) SERVER_MODE="cloud" ;;
        *) SERVER_MODE="local" ;;
    esac
    sed -i "/^SERVER_MODE=/d" "$env_file" 2>/dev/null || true
    echo "SERVER_MODE=$SERVER_MODE" >> "$env_file"
    sync_env
    echo -e "${GREEN}Server mode set to: ${SERVER_MODE}${NC}"
}

bootstrap_secrets() {
    echo -e "${BLUE}Ensuring secure cryptographic tokens...${NC}"
    # Authelia secrets
    JWT_SECRET=$(openssl rand -hex 32)
    SESSION_SECRET=$(openssl rand -hex 32)
    ENCRYPTION_KEY=$(openssl rand -hex 32)

    # Traefik Dashboard auth token
    if [[ -z "$TRAEFIK_DASHBOARD_AUTH_TOKEN" || "$TRAEFIK_DASHBOARD_AUTH_TOKEN" == "" ]]; then
        TRAEFIK_DASHBOARD_AUTH_TOKEN=$(openssl rand -hex 32)
        sed -i "/^TRAEFIK_DASHBOARD_AUTH_TOKEN=/d" "$env_file" 2>/dev/null || true
        echo "TRAEFIK_DASHBOARD_AUTH_TOKEN=$TRAEFIK_DASHBOARD_AUTH_TOKEN" >> "$env_file"
    fi

    # CrowdSec Blocklist Machine Password
    if [[ -z "$CROWDSEC_BLOCKLIST_MACHINE_PASSWORD" || "$CROWDSEC_BLOCKLIST_MACHINE_PASSWORD" == "" ]]; then
        CROWDSEC_BLOCKLIST_MACHINE_PASSWORD=$(openssl rand -hex 16)
        sed -i "/^CROWDSEC_BLOCKLIST_MACHINE_PASSWORD=/d" "$env_file" 2>/dev/null || true
        echo "CROWDSEC_BLOCKLIST_MACHINE_PASSWORD=$CROWDSEC_BLOCKLIST_MACHINE_PASSWORD" >> "$env_file"
    fi

    # Apply Authelia configuration tokens
    local auth_conf="$basefolder/authelia/configuration.yml"
    if [[ -f "$auth_conf" ]]; then
        sed -i "s/JWTTOKENID/$JWT_SECRET/g" "$auth_conf"
        sed -i "s/unsecure_session_secret/$SESSION_SECRET/g" "$auth_conf"
        sed -i "s/encryption_key_secret/$ENCRYPTION_KEY/g" "$auth_conf"
        sed -i "s/example.com/$DOMAIN/g" "$auth_conf"
        sed -i "s/SERVERIP_ID/${SERVERIP:-127.0.0.1}/g" "$auth_conf"
    fi
}

detect_server_ip() {
    if [[ -z "$SERVERIP" || "$SERVERIP" == "SERVERIP_ID" || "$SERVERIP" == "127.0.0.1" ]]; then
        echo -e "${BLUE}Detecting server external IP...${NC}"
        local detected_ip
        detected_ip=$(curl -sSL --max-time 5 https://api.ipify.org 2>/dev/null || curl -sSL --max-time 5 https://ifconfig.me 2>/dev/null || curl -sSL --max-time 5 https://icanhazip.com 2>/dev/null || true)
        detected_ip=$(echo "$detected_ip" | tr -d '[:space:]')
        if [[ -n "$detected_ip" && "$detected_ip" =~ ^[0-9a-fA-F.:]+$ ]]; then
            SERVERIP="$detected_ip"
            sed -i "/^SERVERIP=/d" "$env_file" 2>/dev/null || true
            echo "SERVERIP=$SERVERIP" >> "$env_file"
            echo -e "${GREEN}Detected server external IP: ${SERVERIP}${NC}"
        fi
    fi
}

bootstrap_crowdsec() {
    echo ""
    echo -e "${CYAN}${BOLD}==> Bootstrapping CrowdSec IPS & Traefik Bouncer...${NC}"
    cd "$basefolder/compose"

    # Automatically update static-whitelist.yaml with detected server external IP
    local whitelist_file="$basefolder/crowdsec/config/postoverflows/s01-whitelist/static-whitelist.yaml"
    if [[ -f "$whitelist_file" ]]; then
        if [[ -n "$SERVERIP" && "$SERVERIP" =~ ^[0-9a-fA-F.:]+$ ]]; then
            echo -e "${GREEN}Whitelisting server external IP: ${SERVERIP}${NC}"
            if grep -q "SERVER_IP_PLACEHOLDER" "$whitelist_file"; then
                sed -i "s/SERVER_IP_PLACEHOLDER/$SERVERIP/g" "$whitelist_file"
            elif ! grep -q "$SERVERIP" "$whitelist_file"; then
                sed -i "/^  ip:/a \    - \"$SERVERIP\"" "$whitelist_file"
            fi
        else
            sed -i "/SERVER_IP_PLACEHOLDER/d" "$whitelist_file" 2>/dev/null || true
        fi
    fi

    # Update ddns-whitelist.yaml with current domain if configured
    local ddns_whitelist="$basefolder/crowdsec/config/postoverflows/s01-whitelist/ddns-whitelist.yaml"
    if [[ -f "$ddns_whitelist" && -n "$DOMAIN" && "$DOMAIN" != "example.com" ]]; then
        sed -i "s/vpn\.example\.com/vpn.$DOMAIN/g" "$ddns_whitelist" 2>/dev/null || true
    fi

    # Ensure external proxy network exists
    local net_name="${DOCKERNETWORK:-proxy}"
    if ! docker network inspect "$net_name" >/dev/null 2>&1; then
        echo -e "${BLUE}Creating external Docker network '${net_name}'...${NC}"
        docker network create --driver=bridge "$net_name" 2>/dev/null || true
    fi

    # Start CrowdSec engine first
    echo -e "${BLUE}Starting CrowdSec service...${NC}"
    $DOCKER_COMPOSE up -d crowdsec

    # Wait up to 30 seconds for CrowdSec LAPI
    echo -e "${BLUE}Waiting for CrowdSec Local API (LAPI) readiness...${NC}"
    local attempts=0
    while [[ $attempts -lt 30 ]]; do
        if docker exec crowdsec cscli version >/dev/null 2>&1; then
            break
        fi
        sleep 1
        attempts=$((attempts + 1))
    done

    # 1. Traefik Bouncer Key
    if [[ -z "$CROWDSEC_BOUNCER_KEY" || "$CROWDSEC_BOUNCER_KEY" == "CROWDSEC_BOUNCER_KEY_ID" ]]; then
        echo -e "${BLUE}Registering Traefik Bouncer in CrowdSec...${NC}"
        # Remove existing if any
        docker exec crowdsec cscli bouncers delete traefik-bouncer >/dev/null 2>&1 || true
        CROWDSEC_BOUNCER_KEY=$(docker exec crowdsec cscli bouncers add traefik-bouncer -o raw 2>/dev/null | tr -d '\r\n' || true)

        if [[ -n "$CROWDSEC_BOUNCER_KEY" ]]; then
            sed -i "/^CROWDSEC_BOUNCER_KEY=/d" "$env_file" 2>/dev/null || true
            echo "CROWDSEC_BOUNCER_KEY=$CROWDSEC_BOUNCER_KEY" >> "$env_file"
            echo -e "${GREEN}Traefik bouncer key successfully generated!${NC}"
        fi
    fi

    # 2. Blocklist Importer Bouncer Key
    if [[ -z "$CROWDSEC_BLOCKLIST_BOUNCER_KEY" ]]; then
        echo -e "${BLUE}Registering Blocklist Import Bouncer in CrowdSec...${NC}"
        docker exec crowdsec cscli bouncers delete blocklist-import >/dev/null 2>&1 || true
        CROWDSEC_BLOCKLIST_BOUNCER_KEY=$(docker exec crowdsec cscli bouncers add blocklist-import -o raw 2>/dev/null | tr -d '\r\n' || true)
        if [[ -n "$CROWDSEC_BLOCKLIST_BOUNCER_KEY" ]]; then
            sed -i "/^CROWDSEC_BLOCKLIST_BOUNCER_KEY=/d" "$env_file" 2>/dev/null || true
            echo "CROWDSEC_BLOCKLIST_BOUNCER_KEY=$CROWDSEC_BLOCKLIST_BOUNCER_KEY" >> "$env_file"
        fi
    fi

    # 3. Blocklist Importer Machine Registration
    echo -e "${BLUE}Registering Blocklist Import Machine in CrowdSec...${NC}"
    docker exec crowdsec cscli machines delete "${CROWDSEC_BLOCKLIST_MACHINE_ID:-blocklist-import}" >/dev/null 2>&1 || true
    docker exec crowdsec cscli machines add "${CROWDSEC_BLOCKLIST_MACHINE_ID:-blocklist-import}" --password "${CROWDSEC_BLOCKLIST_MACHINE_PASSWORD}" -f - >/dev/null 2>&1 || true

    # Inject keys into middlewares.toml
    local mw_toml="$basefolder/traefik/rules/middlewares.toml"
    if [[ -f "$mw_toml" ]]; then
        sed -i "s#example.com#$DOMAIN#g" "$mw_toml"
        sed -i "s#https:$DOMAIN#https://$DOMAIN#g" "$mw_toml"
        if [[ -n "$CROWDSEC_BOUNCER_KEY" ]]; then
            sed -i "s/CROWDSEC_BOUNCER_KEY_ID/$CROWDSEC_BOUNCER_KEY/g" "$mw_toml"
            sed -i "s/crowdsecLapiKey = \".*\"/crowdsecLapiKey = \"$CROWDSEC_BOUNCER_KEY\"/g" "$mw_toml"
        fi
    fi

    sync_env
}

deploy_stack() {
    ensure_docker || return 1

    # Ensure Host Pre-Installation has been completed
    if [[ ! -f "$basefolder/.preinstalled" && -f "/opt/dockserver/preinstall/install.sh" ]]; then
        echo -e "${CYAN}${BOLD}==> Applying Host Pre-Installation & System Hardening...${NC}"
        bash "/opt/dockserver/preinstall/install.sh"
    fi

    copy_templates
    sync_env

    # Validate mandatory variables
    if [[ -z "$DOMAIN" || "$DOMAIN" == "example.com" ]]; then
        echo -e "${RED}Error: Please configure a valid Domain before deploying.${NC}"
        sleep 2
        return 1
    fi
    if [[ -z "$CLOUDFLARE_EMAIL" || "$CLOUDFLARE_EMAIL" == "CF-EMAIL" ]]; then
        echo -e "${RED}Error: Please configure your Cloudflare Email before deploying.${NC}"
        sleep 2
        return 1
    fi
    if [[ -z "$CLOUDFLARE_API_KEY" || "$CLOUDFLARE_API_KEY" == "CF-API-KEY" ]]; then
        echo -e "${RED}Error: Please configure your Cloudflare Global API Key before deploying.${NC}"
        sleep 2
        return 1
    fi

    # Ensure Authelia password has been hashed
    if [[ ! -f "$basefolder/authelia/users_database.yml" ]] || grep -q '<PASSWORD>' "$basefolder/authelia/users_database.yml" 2>/dev/null; then
        echo -e "${YELLOW}Authelia admin password has not been generated yet.${NC}"
        prompt_password
    fi

    detect_server_ip
    bootstrap_secrets
    bootstrap_crowdsec

    echo ""
    echo -e "${CYAN}${BOLD}==> Deploying Edge Gateway Stack (Traefik, CrowdSec, Authelia, Dashboard)...${NC}"
    cd "$basefolder/compose"
    $DOCKER_COMPOSE pull
    $DOCKER_COMPOSE up -d --remove-orphans

    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}    🚀  Edge Gateway Successfully Deployed!                              ${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Traefik Proxy:       ${CYAN}https://traefik.${DOMAIN}${NC}"
    echo -e "  Authelia SSO / MFA:  ${CYAN}https://authelia.${DOMAIN}${NC}"
    echo -e "  Traefik Dashboard:   ${CYAN}https://traefik-dashboard.${DOMAIN}${NC}"
    echo -e "  Server Environment:  ${YELLOW}${SERVER_MODE:-local}${NC}"
    echo ""
    echo -e "  ${BOLD}Security Stack Status:${NC}"
    echo -e "  • CrowdSec IPS:      ${GREEN}Active${NC} (Parsing Traefik access logs)"
    echo -e "  • Traefik Bouncer:   ${GREEN}Active${NC} (Plugin stream mode via LAPI)"
    echo -e "  • Blocklist Feeds:   ${GREEN}Active${NC} (28+ intelligence feeds)"
    echo -e "  • Custom Error Pages:${GREEN}Active${NC} (4xx/5xx handling)"
    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -erp "Press [ENTER] to return to menu: " _ </dev/tty
}

main_menu() {
    while true; do
        sync_env
        clear
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}    🚀  DockServer - Edge Gateway (Traefik v3 + CrowdSec + Authelia)       ${NC}"
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}[1] Domain:${NC}                   ${YELLOW}${DOMAIN:-Not set}${NC}"
        echo -e "  ${BOLD}[2] Authelia Username:${NC}        ${YELLOW}${AUTHELIA_USER:-admin}${NC}"
        echo -e "  ${BOLD}[3] Authelia Password:${NC}        ${YELLOW}********${NC}"
        echo -e "  ${BOLD}[4] Cloudflare Email:${NC}         ${YELLOW}${CLOUDFLARE_EMAIL:-Not set}${NC}"
        echo -e "  ${BOLD}[5] Cloudflare Global Key:${NC}    ${YELLOW}${CLOUDFLARE_API_KEY:+Configured (Hidden)}${CLOUDFLARE_API_KEY:-Not set}${NC}"
        echo -e "  ${BOLD}[6] Cloudflare Zone ID:${NC}       ${YELLOW}${DOMAIN1_ZONE_ID:-Not set}${NC}"
        echo -e "  ${BOLD}[7] Server Environment Mode:${NC}  ${GREEN}${SERVER_MODE:-local}${NC}"
        echo ""
        echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${GREEN}${BOLD}[ D ] Deploy Edge Gateway Stack (Traefik + CrowdSec + Authelia)${NC}"
        echo -e "  ${BLUE}${BOLD}[ S ] Status / Container Healthcheck${NC}"
        echo -e "  ${YELLOW}${BOLD}[ R ] Restart Gateway Stack${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}[ Z / Exit ] - Back to Main Menu${NC}"
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        read -erp "Select Option and Press [ENTER]: " choice </dev/tty

        case $choice in
            1) prompt_domain ;;
            2) prompt_displayname ;;
            3) prompt_password ;;
            4) prompt_cfemail ;;
            5) prompt_cfkey ;;
            6) prompt_cfzoneid ;;
            7) prompt_servermode ;;
            d|D) deploy_stack ;;
            s|S)
                clear
                echo -e "${CYAN}${BOLD}==> Container Status${NC}"
                docker ps --filter "name=traefik|crowdsec|authelia|cf-companion" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
                echo ""
                read -erp "Press [ENTER] to continue: " _ </dev/tty
                ;;
            r|R)
                cd "$basefolder/compose"
                $DOCKER_COMPOSE restart traefik authelia crowdsec cf-companion
                echo -e "${GREEN}Gateway restarted.${NC}"
                sleep 2
                ;;
            z|Z|exit|EXIT|close) break ;;
            *) ;;
        esac
    done
}

# Run
copy_templates
main_menu
