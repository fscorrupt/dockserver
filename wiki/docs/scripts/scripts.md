# Maintenance & Utility Scripts

DockServer includes several utility and maintenance scripts located under `/opt/dockserver/scripts/` to help you manage and optimize your server.

---

## 🧹 Disk & Docker Cleanup

### Docker Image & Cache Prune
Removes dangling images, stopped containers, and unused builder caches:
```bash
sudo bash /opt/dockserver/scripts/docker/dockerprune.sh
```

### System Disk Cleanup
Cleans APT package caches, rotated systemd logs, and temporary files:
```bash
sudo bash /opt/dockserver/scripts/disk_cleanup.sh
```

---

## 🎬 Plex Optimization Scripts

### Empty Trash Across Libraries
Removes unavailable items from Plex media libraries via Plex SQLite or API:
```bash
sudo bash /opt/dockserver/scripts/plex/plex-empty-trash.sh
```

### Optimize Plex SQLite Database
Performs a `VACUUM` and re-indexing on Plex's SQLite database to maintain peak performance:
```bash
sudo bash /opt/dockserver/scripts/plex/plex-optimize-db.sh
```

---

## 💾 Application Backups

### Automated Daily App Backups
Backs up running containers to `/mnt/downloads/appbackups/local/`:
```bash
sudo bash /opt/dockserver/scripts/backup/backupdate.sh
```
*(See the [Backup Guide](../commands/backup.md) for automated cron scheduling)*

---

## 🔒 Security & IP Ban Utilities

The `/opt/dockserver/scripts/security/` directory contains helper scripts for inspecting and blocking suspicious IP addresses. Note that CrowdSec now manages bans automatically at the Traefik reverse proxy level.
