# Installation Guide

Setting up DockServer takes just a few minutes. Follow these simple steps to install and configure your server.

---

## 📋 Prerequisites & System Requirements

- **Operating System**:
  - Ubuntu 24.04 LTS
  - Ubuntu 22.04 LTS
  - Debian 12
- **Hardware**:
  - 2+ CPU cores (4+ cores recommended for media transcoding)
  - 4 GB+ RAM (8 GB+ recommended)
  - 20 GB+ free disk space
- **Cloudflare Account**:
  - A registered domain (free or paid) with DNS nameservers pointed to Cloudflare.
  - Free Cloudflare account tier is completely sufficient.

---

## Step 1: Prepare Cloudflare DNS

DockServer uses Cloudflare to automatically issue wildcard SSL certificates (`*.yourdomain.com`) and create subdomains for all your apps.

1. In your [Cloudflare Dashboard](https://dash.cloudflare.com/), navigate to your domain's **DNS** tab.
2. Add an **A-Record**:
   - **Type**: `A`
   - **Name**: `@` (or your root domain)
   - **IPv4 Address**: Your server's public IP
   - **Proxy Status**: `Proxied` (Orange cloud) or `DNS only` (Grey cloud)
3. In **SSL/TLS** settings:
   - Set encryption mode to **Full** *(do not use Full/Strict until certificates are issued)*.
   - Enable **Always Use HTTPS**.
4. Retrieve your credentials:
   - **Cloudflare Email**: Your Cloudflare login email.
   - **Global API Key**: Go to **My Profile** > **API Tokens** > **Global API Key** > **View**.
   - **Zone ID**: Found on your domain's **Overview** page in the right sidebar.

---

## Step 2: Run the One-Line Installer

Connect to your server via SSH and execute:

```bash
sudo wget -qO- https://raw.githubusercontent.com/dockserver/dockserver/master/wgetfile.sh | sudo bash
```

The installer will:
- Install official Docker Engine and Docker Compose v2.
- Configure system prerequisites and Docker networking.
- Install the `dockserver` CLI tool to `/usr/bin/dockserver`.

---

## Step 3: Launch Setup

Start the interactive control center:

```bash
sudo dockserver -i
```

### 1. Deploy the Edge Gateway
Select **`[ 1 ] Edge Gateway`**:
1. Enter your **Domain Name** (e.g. `yourdomain.com`).
2. Set an **Authelia Username** and **Password** (used to log into your secured apps).
3. Enter your **Cloudflare Email**, **Global API Key**, and **Zone ID**.
4. Choose your **Server Environment Mode**:
   - **`cloud`**: For VPS/Dedicated servers (Hetzner, Vultr, etc.) with cloud storage mounts.
   - **`local`**: For Home Labs / LAN servers (preserves local router DNS).
5. Select **`[ D ] Deploy Edge Gateway`**.

Traefik v3, CrowdSec IPS, Authelia SSO, Traefik Log Dashboard, and Cloudflare Companion will bootstrap and start automatically.

### 2. Deploy Applications
Select **`[ 2 ] Applications Catalog`** to install:
- **Media Servers**: Plex, Jellyfin, Emby
- **Media Managers**: Radarr, Sonarr, Lidarr, Prowlarr, Bazarr
- **Download Clients**: qBittorrent, Deluge, SABnzbd
- **Utilities**: Heimdall, Dozzle, WireGuard, Vaultwarden, and more.

All installed applications are automatically secured behind your domain with SSL certificates and Authelia protection!
