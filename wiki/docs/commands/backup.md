# Application Backup Guide

DockServer includes automated backup capabilities to safeguard your application configurations, databases, and user settings.

---

## 💾 Daily Automated Backup Script

DockServer includes a built-in backup script located at:
```
/opt/dockserver/scripts/backup/backupdate.sh
```

### What It Backs Up
The script iterates through all running containers and backs up their `/opt/appdata/<app>` directories into compressed archives using `pigz` (parallel gzip):
```
/mnt/downloads/appbackups/local/<app_name>.tar.gz
```

For databases and media servers (like Plex, Emby, Radarr, and Sonarr), it temporarily pauses the container to ensure database consistency before creating the archive.

---

## ⚡ Running a Manual Backup

To trigger a backup immediately from the terminal:

```bash
sudo bash /opt/dockserver/scripts/backup/backupdate.sh
```

---

## ⏰ Scheduling Automated Backups (Cron)

To run backups automatically every day at 3:00 AM, add a cron job:

```bash
sudo crontab -e
```

Add the following line:
```cron
0 3 * * * /bin/bash /opt/dockserver/scripts/backup/backupdate.sh > /var/log/dockserver_backup.log 2>&1
```

---

## 🔔 Discord Webhook Notifications (Optional)

You can receive a notification in your Discord channel whenever a backup completes:
1. Open `/opt/dockserver/scripts/backup/backupdate.sh` with a text editor:
   ```bash
   sudo nano /opt/dockserver/scripts/backup/backupdate.sh
   ```
2. Set your Discord webhook URL on line 13:
   ```bash
   WEBHOOK_URL="https://discord.com/api/webhooks/your/webhook/url"
   ```
3. Save and exit.
