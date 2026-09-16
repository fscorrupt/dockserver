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

## What is DockServer?

**DockServer** is a modern, turnkey home server and media automation stack. It deploys **Docker**, **Traefik v3**, **CrowdSec IPS**, **Authelia Single Sign-On**, and an automated catalog of 80+ media, download, and management apps with a single command.

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

## 📖 Documentation & Community

- **Official Wiki**: [https://dockserver.github.io/dockserver/](https://dockserver.github.io/dockserver/)
- **Discord Community**: [Join our Discord Server](https://discord.gg/FYSvu83caM)
- **Issue Tracker**: [GitHub Issues](https://github.com/dockserver/dockserver/issues)

---

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->

### Contributors

<table>
<tr>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/doob187>
            <img src=https://avatars.githubusercontent.com/u/60312740?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=doob187/>
            <br />
            <sub style="font-size:14px"><b>doob187</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/fscorrupt>
            <img src=https://avatars.githubusercontent.com/u/45659314?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=FSCorrupt/>
            <br />
            <sub style="font-size:14px"><b>FSCorrupt</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/drag0n141>
            <img src=https://avatars.githubusercontent.com/u/44865095?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=DrAg0n141/>
            <br />
            <sub style="font-size:14px"><b>DrAg0n141</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/aelfa>
            <img src=https://avatars.githubusercontent.com/u/60222501?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=Aelfa/>
            <br />
            <sub style="font-size:14px"><b>Aelfa</b></sub>
        </a>
    </td>
</tr>
<tr>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/cyb3rgh05t>
            <img src=https://avatars.githubusercontent.com/u/5200101?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=cyb3rgh05t/>
            <br />
            <sub style="font-size:14px"><b>cyb3rgh05t</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/justinglock40>
            <img src=https://avatars.githubusercontent.com/u/23133649?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=justinglock40/>
            <br />
            <sub style="font-size:14px"><b>justinglock40</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/mrfret>
            <img src=https://avatars.githubusercontent.com/u/72273384?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=mrfret/>
            <br />
            <sub style="font-size:14px"><b>mrfret</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/dan3805>
            <img src=https://avatars.githubusercontent.com/u/35934387?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=DoCtEuR3805 | FRENCH-QC/>
            <br />
            <sub style="font-size:14px"><b>DoCtEuR3805 | FRENCH-QC</b></sub>
        </a>
    </td>
</tr>
<tr>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/brtbach>
            <img src=https://avatars.githubusercontent.com/u/24246495?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=brtbach/>
            <br />
            <sub style="font-size:14px"><b>brtbach</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/renovate-bot>
            <img src=https://avatars.githubusercontent.com/u/25180681?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=Mend Renovate/>
            <br />
            <sub style="font-size:14px"><b>Mend Renovate</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/ramsaytc>
            <img src=https://avatars.githubusercontent.com/u/16809662?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=ramsaytc/>
            <br />
            <sub style="font-size:14px"><b>ramsaytc</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/Shayne55434>
            <img src=https://avatars.githubusercontent.com/u/37595910?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=Shayne/>
            <br />
            <sub style="font-size:14px"><b>Shayne</b></sub>
        </a>
    </td>
</tr>
<tr>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/Nossersvinet>
            <img src=https://avatars.githubusercontent.com/u/83166809?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=Nossersvinet/>
            <br />
            <sub style="font-size:14px"><b>Nossersvinet</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/ookla-ariel-ride>
            <img src=https://avatars.githubusercontent.com/u/42082417?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=Ookla, Ariel, Ride!/>
            <br />
            <sub style="font-size:14px"><b>Ookla, Ariel, Ride!</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/ImgBotApp>
            <img src=https://avatars.githubusercontent.com/u/31427850?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=Imgbot/>
            <br />
            <sub style="font-size:14px"><b>Imgbot</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/townsmcp>
            <img src=https://avatars.githubusercontent.com/u/14061617?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=James Townsend/>
            <br />
            <sub style="font-size:14px"><b>James Townsend</b></sub>
        </a>
    </td>
</tr>
<tr>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/red-daut>
            <img src=https://avatars.githubusercontent.com/u/78737369?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=Red Daut/>
            <br />
            <sub style="font-size:14px"><b>Red Daut</b></sub>
        </a>
    </td>
    <td align="center" style="word-wrap: break-word; width: 75.0; height: 75.0">
        <a href=https://github.com/domesticwarlord86>
            <img src=https://avatars.githubusercontent.com/u/57776315?v=4 width="50;"  style="border-radius:50%;align-items:center;justify-content:center;overflow:hidden;padding-top:10px" alt=domesticwarlord86/>
            <br />
            <sub style="font-size:14px"><b>domesticwarlord86</b></sub>
        </a>
    </td>
</tr>
</table>
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->
