# DockServer CLI Reference

DockServer includes a unified command-line utility accessible via `dockserver` or `sudo dockserver`.

---

## ⚡ Quick Reference

| Command | Description |
| :--- | :--- |
| **`sudo dockserver -i`** | Open the interactive menu (Control Center) |
| **`sudo dockserver -a <app>`** | Fast-install an application (e.g. `dockserver -a plex`) |
| **`sudo dockserver -u`** | Pull and update edge gateway containers |
| **`sudo dockserver -m`** | 1-Click upgrade tool for existing legacy installations |
| **`sudo dockserver --mode <mode>`** | Switch server environment mode (`cloud` or `local`) |
| **`dockserver -h`** | Display CLI help and command options |

---

## 📖 Command Details

### Interactive Control Center
```bash
sudo dockserver -i
```
Launches the full interactive terminal menu (TUI). From here you can:
- Configure and deploy Traefik v3, CrowdSec, and Authelia.
- Browse and install apps from the 80+ application catalog.
- Run host pre-installations and GPU driver setups.
- Toggle between Cloud and Local server modes.

---

### Direct Application Installation
```bash
sudo dockserver -a <app_name>
```
Installs an application directly without opening the interactive menu:
```bash
sudo dockserver -a plex
sudo dockserver -a radarr
sudo dockserver -a qbittorrent
```

---

### Update Gateway Containers
```bash
sudo dockserver -u
```
Pulls the latest images for Traefik, CrowdSec, Authelia, and Cloudflare Companion, and recreates the containers cleanly.

---

### 1-Click Upgrade & Migration
```bash
sudo dockserver -m
```
Upgrades an existing legacy DockServer setup to modern Traefik v3, CrowdSec IPS, and the Traefik Log Dashboard while preserving existing certificates, passwords, and `.env` settings.

---

### Configure Server Environment Mode
```bash
sudo dockserver --mode <cloud|local>
```
- **`cloud`**: For cloud VPS or dedicated servers (Hetzner, Vultr, etc.) utilizing remote storage mounts.
- **`local`**: For bare-metal home servers and LANs. Prevents overriding local router DNS and skips cloud mounters.
