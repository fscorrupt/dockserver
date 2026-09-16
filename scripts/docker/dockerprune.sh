#!/usr/bin/env bash
# shellcheck shell=bash
###############################################################
# DockServer - Docker Maintenance & Prune Tool                #
# Modernized for Ubuntu 24.04, 22.04 & Debian 12              #
###############################################################
set -e

if [[ $EUID -ne 0 ]]; then
    sudo "$0" "$@"
    exit $?
fi

run_prune() {
    echo ""
    echo "Running Docker system prune..."
    docker system prune -af --volumes
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅  Docker Prune Completed Successfully!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    sleep 2
    exit 0
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    🚀  DockServer Docker Maintenance Cleaner"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  This will remove:"
echo "  • All stopped containers"
echo "  • All unused networks"
echo "  • All unused/dangling images"
echo "  • All build cache"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -erp "Proceed with prune? (y/N): " choice </dev/tty

case $choice in
    y|Y|yes|YES) run_prune ;;
    *) echo "Prune cancelled." ;;
esac
