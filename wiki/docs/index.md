# **DockServer**

<p align="center">
    <a href="https://dockserver.github.io/dockserver/">
      <img src="https://raw.githubusercontent.com/dockserver/dockserver/master/wiki/docs/img/dockservee_animated.gif" alt="DockServer Banner" width="700">
    </a>
</p>

<p align="center">
    <a href="https://discord.gg/FYSvu83caM">
        <img src="https://img.shields.io/discord/830478558995415100?color=7289da&label=Discord&logo=discord&logoColor=white" alt="Discord">
    </a>
    <a href="https://github.com/dockserver/dockserver/releases/latest">
        <img src="https://img.shields.io/github/v/release/dockserver/dockserver?color=blue&label=Latest%20Release&logo=github" alt="Release">
    </a>
    <a href="https://github.com/dockserver/dockserver/blob/master/LICENSE">
        <img src="https://img.shields.io/github/license/dockserver/dockserver?label=License&logo=mit" alt="License">
    </a>
</p>

---

## Welcome to the DockServer Wiki

**DockServer** is an automated, turnkey server and media automation stack. It integrates **Docker**, **Traefik v3**, **CrowdSec IPS**, **Authelia Single Sign-On**, and an automated catalog of 80+ media, download, and management apps with a single command.

---

## ⚡ Quick Start in 3 Steps

### Step 1: Cloudflare Preparation
DockServer uses Cloudflare to automatically issue Let's Encrypt wildcard SSL certificates and manage DNS subdomains.
1. Add an **A-Record** in Cloudflare pointing your domain (e.g. `yourdomain.com`) to your server's public IP.
2. In Cloudflare **SSL/TLS**, set encryption mode to **Full**.
3. Retrieve your **Global API Key** and **Zone ID** from your [Cloudflare Dashboard](https://dash.cloudflare.com/).

### Step 2: One-Line Installation
Run the installer on your server (Ubuntu 24.04, Ubuntu 22.04, or Debian 12):

```bash
sudo wget -qO- https://raw.githubusercontent.com/dockserver/dockserver/master/wgetfile.sh | sudo bash
```

### Step 3: Interactive Setup
Launch the control panel:

```bash
sudo dockserver -i
```

1. Select **`[ 1 ] Edge Gateway`**: Enter your domain and Cloudflare credentials. Traefik v3, CrowdSec, Authelia, and the real-time Log Dashboard will deploy automatically.
2. Select **`[ 2 ] Applications Catalog`**: Choose and install your desired apps (Plex, Jellyfin, Radarr, Sonarr, qBittorrent, etc.).

---

## 🌐 Server Modes: Cloud vs. Local

During setup or via the CLI, choose the mode that matches your server environment:

| Mode | Best For | What It Does |
| :--- | :--- | :--- |
| **`cloud`** | VPS / Dedicated hosts (Hetzner, Vultr, OVH) | Enables cloud mounting and remote storage tools (`mount`, `uploader`). |
| **`local`** | Home Labs, bare-metal, unRAID, Proxmox LXC | Disables cloud storage mounters and preserves your local router LAN DNS. |

Switch mode anytime:
```bash
sudo dockserver --mode local    # For home / local servers
sudo dockserver --mode cloud    # For cloud VPS servers
```

---

## 🛠️ CLI Quick Reference

```bash
dockserver -i                # Open interactive control panel
dockserver -a <app_name>     # Quick-install an app (e.g. dockserver -a plex)
dockserver -u                # Pull updates for edge gateway containers
dockserver -m                # 1-Click upgrade for existing legacy DockServer setups
dockserver --mode <mode>     # Set server mode: 'cloud' or 'local'
dockserver -h                # Show help and CLI options
```

---

## 🚀 Key Features

- **Traefik v3 Edge Gateway**: Automated Let's Encrypt wildcard certificates (`*.yourdomain.com`), HTTP/3 (QUIC) support, and real-client IP forwarding via Cloudflare.
- **CrowdSec IPS**: Gateway-level intrusion prevention that drops malicious traffic instantly and synchronizes with 28+ global threat feeds.
- **Authelia SSO & 2FA**: Secure your private web services with Single Sign-On and optional two-factor authentication.
- **Real-Time Traffic Dashboard**: Live request analytics, connection rates, and geographic maps at `https://traefik-dashboard.yourdomain.com`.
- **Automatic Subdomains (CF-Companion)**: Deploying an app automatically registers its DNS record in Cloudflare.
- **Hardware Acceleration**: Out-of-the-box support for Intel QuickSync, AMD Radeon, and NVIDIA GPUs for hardware transcoding.
- **Safe 1-Click Migration**: Existing users can upgrade seamlessly to Traefik v3 and CrowdSec with `dockserver -m` without losing configs or certificates.

---

## 🖥️ System Requirements

- **Operating System**: Ubuntu 24.04 LTS, Ubuntu 22.04 LTS, or Debian 12
- **CPU**: 2 cores minimum (4+ cores recommended for media transcoding)
- **RAM**: 4 GB minimum (8 GB+ recommended)
- **Storage**: 20 GB+ free disk space
- **Prerequisites**: A domain with DNS managed by Cloudflare (free tier is fully supported)

---

## 📚 Explore the Documentation

- [Step-by-Step Installation](install/install.md)
- [Cloudflare Setup Guide](install/cloudflare.md)
- [Traefik v3 Reverse Proxy](install/traefik.md)
- [CrowdSec Intrusion Prevention](install/crowdsec.md)
- [Authelia Single Sign-On](install/authelia.md)
- [Cloudflare Companion](install/cf-companion.md)
- [Migration & Upgrade Guide](install/migration.md)
- [CLI Commands Reference](commands/commands.md)
- [Proxmox LXC Setup](lxc/lxc.md)
