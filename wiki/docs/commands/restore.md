# Application Restore Guide

Restoring an application from a backup in DockServer is fast and straightforward.

---

## 🔄 How to Restore an Application

When you need to restore an application's configuration from a backup archive (`.tar.gz`):

### Step 1: Stop the Application Container
```bash
docker stop <app_name>
```

### Step 2: Extract the Backup Archive
Extract the backup archive located in `/mnt/downloads/appbackups/local/` into `/opt/appdata/<app_name>`:

```bash
# Example: Restoring Radarr
sudo rm -rf /opt/appdata/radarr/*
sudo tar -xzvf /mnt/downloads/appbackups/local/radarr.tar.gz -C /opt/appdata/radarr/
```

### Step 3: Fix File Permissions
Ensure the restored files are owned by the standard DockServer user (`1000:1000`):

```bash
sudo chown -R 1000:1000 /opt/appdata/<app_name>
```

### Step 4: Restart the Application
```bash
docker start <app_name>
```

The application will launch with its restored databases, settings, and library metadata.
