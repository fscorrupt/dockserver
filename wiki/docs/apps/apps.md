# Applications Catalog

DockServer includes a pre-configured catalog of over 80+ self-hosted applications across media, downloads, automation, and system utilities.

---

## ⚡ How to Install Applications

You can install any application in two simple ways:

### 1. Interactive Menu
Run `sudo dockserver -i` and choose **`[ 2 ] Applications Catalog`**. Select an application category and choose the app you want to install.

### 2. Fast Direct Command
Install any application directly by name:
```bash
sudo dockserver -a plex
sudo dockserver -a radarr
sudo dockserver -a sonarr
sudo dockserver -a qbittorrent
sudo dockserver -a jellyfin
```

---

## 📂 Application Categories

| Category | Popular Applications |
| :--- | :--- |
| **Media Servers** | Plex, Jellyfin, Emby |
| **Media Managers** | Radarr, Sonarr, Lidarr, Readarr, Bazarr, Prowlarr, Tautulli |
| **Download Clients** | qBittorrent, Deluge, SABnzbd, NZBGet, JDownloader2 |
| **Encoders** | HandBrake, Tdarr |
| **Self-Hosted Utilities** | Bitwarden/Vaultwarden, Home Assistant, Nextcloud, WireGuard, Pi-hole |
| **Dashboards & Monitoring** | Traefik Log Dashboard, Dozzle, Heimdall, Netdata |

---

## 🔒 Automatic SSL & Authentication

Every application installed through DockServer is automatically:
- Connected to the internal Docker network (`traefik_proxy`).
- Assigned an automated Cloudflare CNAME record (`app.yourdomain.com`).
- Issued an automated Let's Encrypt SSL certificate.
- Protected behind Authelia Single Sign-On (with public bypass for mobile apps like Plex/Jellyfin and API webhook endpoints).
