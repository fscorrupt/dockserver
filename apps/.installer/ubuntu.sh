#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Application Management & Installation Engine   #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################
set -e

basefolder="/opt/appdata"
appfolder="/opt/dockserver/apps"
env_file="$basefolder/compose/.env"
storage="/mnt/downloads"

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

sync_env() {
    if [[ -f "/opt/dockserver/apps/.subactions/envmigrate.sh" ]]; then
        bash "/opt/dockserver/apps/.subactions/envmigrate.sh"
    fi
    if [[ -f "$env_file" ]]; then
        # shellcheck disable=SC1090
        source "$env_file"
    fi
}

check_traefik_prereq() {
    if [[ -f "/opt/dockserver/scripts/docker/ensure_docker.sh" ]]; then
        bash "/opt/dockserver/scripts/docker/ensure_docker.sh" >/dev/null 2>&1 || true
    fi

    if ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qE '^traefik$'; then
        echo ""
        echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}${BOLD}  ⛔  Traefik & Edge Gateway must be deployed first!      ${NC}"
        echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "Please deploy Traefik & Authelia via option [ 1 ] from the main menu."
        echo ""
        read -erp "Press [ENTER] to return..." _ </dev/tty
        exit 0
    fi
}

headinterface() {
    while true; do
        sync_env
        clear
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}    🚀  DockServer - Applications Management                               ${NC}"
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  Server Environment Mode: ${YELLOW}${SERVER_MODE:-cloud}${NC}"
        echo ""
        echo -e "  ${BOLD}[ 1 ] Install  Applications${NC}"
        echo -e "  ${BOLD}[ 2 ] Remove   Applications${NC}"
        echo -e "  ${BOLD}[ 3 ] Backup   Applications${NC}"
        echo -e "  ${BOLD}[ 4 ] Restore  Applications${NC}"
        echo ""
        echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}[ Z / Exit ] - Back to Main Menu${NC}"
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        read -erp "Select Option and Press [ENTER]: " headsection </dev/tty

        case $headsection in
            1) clear && category_menu ;;
            2) clear && removeapp ;;
            3) clear && backupstorage ;;
            4) clear && restorestorage ;;
            z|Z|exit|EXIT|close) exit 0 ;;
            *) ;;
        esac
    done
}

category_menu() {
    while true; do
        sync_env
        clear
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}    🚀  Application Categories                                            ${NC}"
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        local categories=()
        for d in "$appfolder"/*/; do
            local cat_name
            cat_name=$(basename "$d")
            # Skip hidden and internal directories
            if [[ "$cat_name" =~ ^\. ]]; then continue; fi
            categories+=("$cat_name")
            echo -e "  • ${CYAN}${cat_name}${NC}"
        done

        echo ""
        echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}[ Z / Exit ] - Back${NC}"
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        read -erp "Type Category Name and Press [ENTER]: " section </dev/tty

        case $section in
            z|Z|exit|EXIT|close|"") return ;;
            *)
                if [[ -d "$appfolder/$section" && ! "$section" =~ ^\. ]]; then
                    clear
                    app_list_menu "$section"
                else
                    echo -e "${RED}Invalid category name.${NC}"
                    sleep 1
                fi
                ;;
        esac
    done
}

app_list_menu() {
    local cat="$1"
    while true; do
        sync_env
        clear
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}    🚀  Apps in Category: ${CYAN}${cat}${NC}                                  "
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        for f in "$appfolder/$cat"/*.yml; do
            if [[ -f "$f" ]]; then
                local app_name
                app_name=$(basename "$f" .yml)

                # Check Local Mode Cloud-Only tags
                if [[ ("$app_name" == "mount" || "$app_name" == "uploader") ]]; then
                    if [[ "${SERVER_MODE:-cloud}" == "local" ]]; then
                        echo -e "  • ${YELLOW}${app_name} [Cloud Only - Disabled in Local Mode]${NC}"
                    else
                        echo -e "  • ${app_name} (Cloud Only)"
                    fi
                else
                    echo -e "  • ${app_name}"
                fi
            fi
        done

        echo ""
        echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}[ Z / Exit ] - Back${NC}"
        echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        read -erp "Type App Name to install and Press [ENTER]: " typed </dev/tty

        case $typed in
            z|Z|exit|EXIT|close|"") return ;;
            *)
                if [[ -f "$appfolder/$cat/${typed}.yml" ]]; then
                    # Check Local server restrictions
                    if [[ "${SERVER_MODE:-cloud}" == "local" && ("$typed" == "mount" || "$typed" == "uploader") ]]; then
                        echo ""
                        echo -e "${RED}${BOLD}Notice: '${typed}' is a cloud-only utility.${NC}"
                        echo -e "Your server mode is currently set to ${YELLOW}local${NC}."
                        echo "Mount and Uploader are disabled on local servers to prevent interfering with local storage."
                        echo ""
                        read -erp "Press [ENTER] to continue..." _ </dev/tty
                        continue
                    fi

                    runinstall "$cat" "$typed"
                else
                    echo -e "${RED}App '${typed}' not found in category '${cat}'.${NC}"
                    sleep 1
                fi
                ;;
        esac
    done
}

runinstall() {
    local cat="$1"
    local app="$2"
    sync_env

    local app_compose_dir="$basefolder/compose/apps/$app"
    mkdir -p "$app_compose_dir"
    local compose_target="$app_compose_dir/docker-compose.yml"
    local override_target="$app_compose_dir/docker-compose.override.yml"

    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}    🚀  Installing ${CYAN}${app}${NC}...                                   "
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Copy app template to persistent app compose directory
    cp -f "$appfolder/$cat/${app}.yml" "$compose_target"
    rm -f "$override_target"

    # GPU overrides for mediaservers and encoders (requires physical /dev/dri node)
    if [[ "$cat" == "mediaserver" || "$cat" == "encoder" ]]; then
        local pci_gpus
        pci_gpus=$(lspci 2>/dev/null | grep -iE 'vga|display|3d|2d' || true)
        local chosen_gpu=""

        if echo "$pci_gpus" | grep -qi 'nvidia' && command -v nvidia-smi >/dev/null 2>&1 && [[ -d "/dev/dri" || -e "/dev/nvidia0" ]]; then
            chosen_gpu="NVIDIA"
        elif [[ -d "/dev/dri" ]]; then
            if echo "$pci_gpus" | grep -qiE 'amd|ati|radeon'; then
                chosen_gpu="AMD"
            elif echo "$pci_gpus" | grep -qi 'intel'; then
                chosen_gpu="Intel"
            else
                chosen_gpu="Intel"
            fi
        else
            echo -e "${YELLOW}Notice: No /dev/dri hardware node present. Running ${app} in standard CPU mode.${NC}"
        fi

        if [[ -n "$chosen_gpu" && -f "$appfolder/$cat/.gpu/$chosen_gpu.yml" ]]; then
            cp -f "$appfolder/$cat/.gpu/$chosen_gpu.yml" "$override_target"
            sed -i "s/<APP>/${app}/g" "$override_target" 2>/dev/null || true
            echo -e "${GREEN}Applied hardware acceleration override (${chosen_gpu}).${NC}"
        fi
    fi

    # Check custom app overrides
    if [[ -f "$appfolder/$cat/.overwrite/${app}.overwrite.yml" ]]; then
        cp -f "$appfolder/$cat/.overwrite/${app}.overwrite.yml" "$override_target"
    fi

    # Clean up obsolete version attribute for modern Docker Compose v2
    sed -i '/^version:/d' "$compose_target" 2>/dev/null || true
    if [[ -f "$override_target" ]]; then
        sed -i '/^version:/d' "$override_target" 2>/dev/null || true
    fi

    # Ensure app data directory exists
    mkdir -p "$basefolder/$app"
    chown -hR 1000:1000 "$basefolder/$app" 2>/dev/null || true

    # App-specific hooks
    case "$app" in
        vnstat)
            if ! command -v vnstat >/dev/null 2>&1; then
                apt-get install -yqq vnstat 2>/dev/null || true
            fi
            ;;
        plex)
            plexclaim_hook "$compose_target"
            ;;
        jdownloader2)
            mkdir -p "$storage/jdownloader2"
            chown -hR 1000:1000 "$storage/jdownloader2" 2>/dev/null || true
            ;;
        rutorrent)
            mkdir -p "$storage/torrent"/{temp,complete}/{movies,tv,tv4k,movies4k,movieshdr,tvhdr,remux}
            chown -hR 1000:1000 "$storage/torrent" 2>/dev/null || true
            ;;
        lidarr)
            mkdir -p "$storage/amd"
            chown -hR 1000:1000 "$storage/amd" 2>/dev/null || true
            ;;
        readarr)
            mkdir -p "$storage/books"
            chown -hR 1000:1000 "$storage/books" 2>/dev/null || true
            ;;
        youtubedl-material)
            mkdir -p "$basefolder/$app"/{appdata,audio,video,subscriptions}
            mkdir -p "$storage/youtubedl"
            chown -hR 1000:1000 "$basefolder/$app" "$storage/youtubedl" 2>/dev/null || true
            ;;
        handbrake)
            mkdir -p "$storage/handbrake"/{watch,storage,output}
            chown -hR 1000:1000 "$storage/handbrake" 2>/dev/null || true
            ;;
        petio)
            mkdir -p "$basefolder/$app"/{db,config,logs}
            chown -hR 1000:1000 "$basefolder/$app" 2>/dev/null || true
            ;;
        tdarr)
            mkdir -p "$basefolder/$app"/{server,configs,logs,encoders}
            chown -hR 1000:1000 "$basefolder/$app" 2>/dev/null || true
            ;;
    esac

    # Run subactions script if present
    if [[ -f "$appfolder/.subactions/${app}.sh" ]]; then
        bash "$appfolder/.subactions/${app}.sh" || true
    fi

    # Run Ansible playbook if present
    if [[ -f "$appfolder/.subactions/${app}.yml" && -x "$(command -v ansible-playbook)" ]]; then
        ansible-playbook "$appfolder/.subactions/${app}.yml" 2>/dev/null || true
    fi

    # Deploy container via Docker Compose v2
    echo -e "${BLUE}Starting container ${app}...${NC}"
    cd "$app_compose_dir"

    local compose_args=("-f" "$compose_target")
    if [[ -f "$override_target" ]]; then
        compose_args+=("-f" "$override_target")
    fi

    # Include global .env
    if [[ -f "$env_file" ]]; then
        compose_args+=("--env-file" "$env_file")
    fi

    $DOCKER_COMPOSE "${compose_args[@]}" config >/dev/null 2>&1 || {
        echo -e "${RED}Compose configuration test failed for ${app}.${NC}"
        $DOCKER_COMPOSE "${compose_args[@]}" config
        read -erp "Press [ENTER] to return..." _ </dev/tty
        return 1
    }

    $DOCKER_COMPOSE "${compose_args[@]}" up -d --force-recreate

    # Safe Authelia Whitelist Bypass injection for Media/Request/Download apps
    if [[ "$cat" == "mediaserver" || "$cat" == "request" || "$cat" == "downloadclients" || "$app" == "nextcloud" || "$app" == "tautulli" ]]; then
        update_authelia_bypass "add" "$app"
    fi

    # Fail2ban for Overseerr
    if [[ "$app" == "overseerr" ]]; then
        setup_overseerr_f2ban
    fi

    # Set file ownership
    chown -hR 1000:1000 "$basefolder/$app" 2>/dev/null || true

    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if grep -q 'traefik.enable=true' "$compose_target"; then
        echo -e "${GREEN}${BOLD}    🚀  ${app} deployed successfully! => https://${app}.${DOMAIN:-example.com}${NC}"
    else
        echo -e "${GREEN}${BOLD}    🚀  ${app} deployed successfully!${NC}"
    fi
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    sleep 3
}

update_authelia_bypass() {
    local action="$1" # add or remove
    local app="$2"
    local conf="$basefolder/authelia/configuration.yml"
    local py_helper="/opt/dockserver/apps/.subactions/authelia_helper.py"

    if [[ -f "$conf" && -f "$py_helper" && -n "$DOMAIN" ]]; then
        python3 "$py_helper" "$action" "$conf" "${app}.${DOMAIN}" 2>/dev/null || true
        # Reload authelia to apply rules
        if docker ps -a --format '{{.Names}}' | grep -qE '^authelia$'; then
            docker restart authelia >/dev/null 2>&1 || true
        fi
    fi
}

plexclaim_hook() {
    local target_compose="$1"
    echo ""
    echo -e "${CYAN}${BOLD}==> Plex Server Claim Code${NC}"
    echo "Get your claim code from https://www.plex.tv/claim/"
    read -erp "Enter Plex Claim Code (leave empty to skip): " claim </dev/tty
    if [[ -n "$claim" ]]; then
        sed -i "s/PLEX_CLAIM_ID/$claim/g" "$target_compose" 2>/dev/null || true
    fi
}

setup_overseerr_f2ban() {
    local ov2ban="/etc/fail2ban/filter.d/overseerr.local"
    if [[ ! -f "$ov2ban" ]]; then
        cat > "$ov2ban" << 'EOF'
[Definition]
failregex = .*\[info\]\[Auth\]\: Failed sign-in attempt.*"ip":"<HOST>"
EOF
        if systemctl is-active --quiet fail2ban; then
            systemctl reload-or-restart fail2ban.service 2>/dev/null || true
        fi
    fi
}

removeapp() {
    sync_env
    clear
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}    🚀  Remove Applications                                               ${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local running_apps
    running_apps=$(docker ps -a --format '{{.Names}}' | grep -vE '^(traefik|crowdsec.*|authelia|cf-companion|traefik-.*|dockserver)$' || true)

    if [[ -z "$running_apps" ]]; then
        echo "No installed applications found to remove."
        echo ""
        read -erp "Press [ENTER] to return..." _ </dev/tty
        return
    fi

    echo "Running / Installed Containers:"
    echo "$running_apps"
    echo ""
    echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}[ Z / Exit ] - Back${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -erp "Type App Name to remove: " typed </dev/tty

    if [[ "$typed" =~ ^(z|Z|exit|EXIT|close|"") ]]; then return; fi

    if docker ps -a --format '{{.Names}}' | grep -xq "$typed"; then
        echo ""
        echo -e "${RED}${BOLD}Removing ${typed}...${NC}"

        # 1. Stop and remove container
        docker stop "$typed" >/dev/null 2>&1 || true
        docker rm "$typed" >/dev/null 2>&1 || true

        # 2. Remove app compose dir
        rm -rf "$basefolder/compose/apps/$typed" 2>/dev/null || true

        # 3. Prompt for data folder removal
        read -erp "Delete application data in $basefolder/$typed? (y/N): " rm_data </dev/tty
        if [[ "$rm_data" =~ ^[yY]$ ]]; then
            rm -rf "$basefolder/$typed"
            echo -e "${YELLOW}Deleted $basefolder/$typed${NC}"
        fi

        # 4. Remove Authelia rule
        update_authelia_bypass "remove" "$typed"

        # 5. Clean up Cloudflare DNS CNAME record if API key is configured
        if [[ -n "$DOMAIN1_ZONE_ID" && -n "$DOMAIN" && -n "$CLOUDFLARE_EMAIL" && -n "$CLOUDFLARE_API_KEY" ]]; then
            local dns_id
            dns_id=$(curl -sX GET "https://api.cloudflare.com/client/v4/zones/$DOMAIN1_ZONE_ID/dns_records?name=${typed}.${DOMAIN}" \
                -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
                -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
                -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 || true)

            if [[ -n "$dns_id" ]]; then
                curl -sX DELETE "https://api.cloudflare.com/client/v4/zones/$DOMAIN1_ZONE_ID/dns_records/$dns_id" \
                    -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
                    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
                    -H "Content-Type: application/json" >/dev/null 2>&1 || true
                echo -e "${GREEN}Cloudflare DNS record for ${typed}.${DOMAIN} deleted.${NC}"
            fi
        fi

        echo -e "${GREEN}${typed} removed successfully.${NC}"
        sleep 2
    else
        echo -e "${RED}Container '${typed}' not found.${NC}"
        sleep 1
    fi
}

backupstorage() {
    local storage_dir="/mnt/unionfs/appbackups"
    mkdir -p "$storage_dir/local"

    local running_dockers
    running_dockers=$(docker ps -a --format '{{.Names}}' | grep -vE '^(traefik|crowdsec.*|authelia|cf-companion|traefik-.*|dockserver)$' || true)

    clear
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}    🚀  Backup Applications                                               ${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Containers eligible for backup:"
    echo "$running_dockers"
    echo ""
    echo "  [ all ] - Backup all containers"
    echo "  [ Z   ] - Back"
    echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────${NC}"
    read -erp "Type Container Name to Backup: " typed </dev/tty

    if [[ "$typed" =~ ^(z|Z|exit|EXIT|close|"") ]]; then return; fi

    local exclude_file="/opt/dockserver/apps/.backup/backup_excludes"
    local tar_opts="--warning=no-file-changed --ignore-failed-read --absolute-names --use-compress-program=pigz"
    if [[ -f "$exclude_file" ]]; then
        tar_opts="$tar_opts --exclude-from=$exclude_file"
    fi

    if [[ "$typed" == "all" ]]; then
        for app in ${running_dockers}; do
            echo -e "${BLUE}Backing up $app...${NC}"
            tar $tar_opts -C "$basefolder/$app" -pcf "$storage_dir/local/${app}.tar.gz" ./ 2>/dev/null || true
            chown 1000:1000 "$storage_dir/local/${app}.tar.gz" 2>/dev/null || true
        done
        echo -e "${GREEN}All backups completed under $storage_dir/local/${NC}"
    elif [[ -d "$basefolder/$typed" ]]; then
        echo -e "${BLUE}Backing up $typed...${NC}"
        tar $tar_opts -C "$basefolder/$typed" -pcf "$storage_dir/local/${typed}.tar.gz" ./ 2>/dev/null || true
        chown 1000:1000 "$storage_dir/local/${typed}.tar.gz" 2>/dev/null || true
        echo -e "${GREEN}Backup completed: $storage_dir/local/${typed}.tar.gz${NC}"
    fi
    sleep 2
}

restorestorage() {
    local storage_dir="/mnt/unionfs/appbackups/local"
    if [[ ! -d "$storage_dir" ]]; then
        echo "No backups found in $storage_dir."
        sleep 2
        return
    fi

    clear
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}    🚀  Restore Applications                                              ${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    ls -1 "$storage_dir"/*.tar.gz 2>/dev/null | xargs -n 1 basename -s .tar.gz || echo "None found"
    echo ""
    read -erp "Type Container Name to Restore: " typed </dev/tty

    if [[ "$typed" =~ ^(z|Z|exit|EXIT|close|"") ]]; then return; fi

    local archive="$storage_dir/${typed}.tar.gz"
    if [[ -f "$archive" ]]; then
        echo -e "${BLUE}Restoring $typed into $basefolder/$typed...${NC}"
        mkdir -p "$basefolder/$typed"
        unpigz -dc "$archive" | tar pxf - -C "$basefolder/$typed"
        chown -R 1000:1000 "$basefolder/$typed"
        echo -e "${GREEN}Restore complete!${NC}"
    else
        echo -e "${RED}Archive not found: $archive${NC}"
    fi
    sleep 2
}

check_traefik_prereq
headinterface
