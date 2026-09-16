# Migration & Upgrade Guide

Whether you are upgrading an existing DockServer installation or migrating from another server (or legacy platforms like PGblitz and Cloudbox), DockServer makes the process seamless and safe.

---

## ⚡ 1. Upgrading an Existing DockServer Installation (1-Click Tool)

If you have a running legacy DockServer installation (2020–2023), you can upgrade directly to modern **Traefik v3**, **CrowdSec IPS**, and the **Traefik Log Dashboard** with zero data loss.

### Automated Migration Command

Run the migration tool directly from the terminal:

```bash
sudo dockserver -m
```

*(Alternatively, run `sudo dockserver -i` and select **`[ 4 ] Migration Tool`**)*

### What the Migration Tool Does Automatically:
1. **Safety Backup**: Creates a complete timestamped backup of your current configuration in `/opt/appdata/backup_pre_migration_<timestamp>/`.
2. **Preserves SSL Certificates**: Moves your existing Let's Encrypt certificates (`acme.json`) into `/opt/appdata/traefik/acme/acme.json` with correct security permissions (`chmod 600`).
3. **Preserves User Databases**: Retains your existing Authelia user database (`users_database.yml` and `db.sqlite3`) intact so all passwords and 2FA tokens remain valid.
4. **Bootstraps CrowdSec**: Generates bouncer API keys, registers threat feed importers, and injects your server's public IP into `static-whitelist.yaml`.
5. **Modernizes Docker Compose**: Upgrades from legacy Docker Compose to the native Docker Compose v2 plugin.
6. **Zero Configuration Loss**: Preserves your `.env` domain, Cloudflare tokens, and all application configurations.

---

## 📦 2. Migrating from External Seedboxes or Legacy Platforms (PGblitz / Cloudbox)

If you are migrating applications and remote storage from PGblitz, Cloudbox, or another seedbox:

### Step 1: Backup App Data on Old Server
Create an archive of your `/opt/appdata` (or seedbox app directory):

```bash
sudo tar -czvf /root/appdata_backup.tar.gz -C /opt/appdata .
```

You can also run DockServer's backup helper script:
```bash
sudo wget -qO- https://raw.githubusercontent.com/dockserver/dockserver/master/backup.sh | sudo bash
```
This creates `/appbackups` on your remote drive containing compressed archives of each application.

Download your `rclone.conf` and Google Drive Service Account keys (GDSA keys) from `/appdata/plexguide/.blitzkeys` (or `/uploader` and `/mount`).

### Step 2: Install DockServer on New Host
Follow the [Installation Guide](install.md) to install DockServer on Ubuntu 22.04/24.04 or Debian 12, then run:
```bash
sudo dockserver -i
```
Deploy the **Edge Gateway** (`[ 1 ] Edge Gateway`) with your domain and Cloudflare credentials.

### Step 3: Configure Rclone & Service Account Keys
Create the required system directories:
```bash
sudo mkdir -p /opt/appdata/system/{rclone,servicekeys/keys}
sudo chown -R 1000:1000 /opt/appdata
```

1. **Rclone Configuration (`rclone.conf`)**:
   Place your standard `rclone.conf` into `/opt/appdata/system/rclone/rclone.conf`.
   Keep only your storage remotes (e.g. `[gdrive]`, `[tdrive]`, `[tcrypt]`). Remove any GDSA or PGUNION remotes:
   ```ini
   [gdrive]
   type = drive
   client_id = YOUR_CLIENT_ID
   client_secret = YOUR_CLIENT_SECRET
   scope = drive
   token = YOUR_TOKEN

   [tdrive]
   type = drive
   client_id = YOUR_CLIENT_ID
   client_secret = YOUR_CLIENT_SECRET
   scope = drive
   team_drive = YOUR_TEAM_DRIVE_ID
   token = YOUR_TOKEN
   ```

2. **Service Account Configuration (`rclonegdsa.conf`)**:
   Copy your `rclone.conf` to `/opt/appdata/system/servicekeys/rclonegdsa.conf`.
   In this file, keep only the GDSA entries and point `service_account_file` to `/system/servicekeys/keys/`:
   ```ini
   [GDSA1]
   type = drive
   scope = drive
   service_account_file = /system/servicekeys/keys/GDSA1
   team_drive = YOUR_TEAM_DRIVE_ID

   [GDSA2]
   type = drive
   scope = drive
   service_account_file = /system/servicekeys/keys/GDSA2
   team_drive = YOUR_TEAM_DRIVE_ID
   ```

3. **Upload Keys**:
   Upload all service account key files into `/opt/appdata/system/servicekeys/keys/`.
   Ensure keys are named without leading zeros (e.g. `GDSA1`, `GDSA2`, etc.).

4. **Deploy Mount & Uploader**:
   In `dockserver -i`, navigate to the **System** section and deploy `mount` and `uploader`.

### Step 4: Restore Application Data
Extract your app backup archives into `/opt/appdata/<app_name>`:
```bash
sudo tar -xzvf /root/appdata_backup.tar.gz -C /opt/appdata/
sudo chown -R 1000:1000 /opt/appdata/
```
Deploy the corresponding applications via `dockserver -i` > **`[ 2 ] Applications Catalog`**.

---

## 🔧 Google Drive Token Refresh & Troubleshooting

If a Google token expires after a migration or reboot:

1. **Check Mount Logs**:
   ```bash
   sudo tail -n 50 -f /opt/appdata/system/mount/logs/rclone-union.log
   ```

2. **Verify Mount Content**:
   ```bash
   sudo docker exec mount ls -1p /mnt/unionfs
   ```

3. **Refresh Google OAuth Token**:
   If you see `Token Expired` or authentication errors:
   ```bash
   sudo docker stop mount
   sudo fusermount -uzq /mnt/unionfs
   sudo fusermount -uzq /mnt/remotes
   ```
   Install Rclone on the host if not present:
   ```bash
   sudo curl https://rclone.org/install.sh | sudo bash
   ```
   Reconnect the remote using your config:
   ```bash
   cd /opt/appdata/system/rclone
   rclone config reconnect tdrive: --config=rclone.conf
   rclone config reconnect gdrive: --config=rclone.conf
   ```
   Restart mount:
   ```bash
   sudo fusermount -uzq /mnt/unionfs
   sudo docker start mount
   sudo docker logs -f mount
   ```
