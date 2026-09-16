# Container Architecture & Ecosystem

DockServer provides a tailored catalog of Docker containers pre-configured for seamless integration, high performance, and minimal resource utilization.

---

## 🏗️ Architecture & Base Images

### Lightweight Alpine Linux Bases
To keep resource usage low on home servers and VPS instances, DockServer container images utilize **Alpine Linux** base images whenever possible.
Applications using optimized Alpine builds include:
- `radarr`
- `sonarr`
- `lidarr`
- `readarr`
- `bazarr`
- `sabnzbd`
- `duplicati`
- And many more in the catalog!

Alpine bases result in smaller image downloads, faster startup times, reduced RAM usage, and a significantly smaller attack surface.

### Upstream Foundation & Compatibility
DockServer container templates build upon proven container designs established by the open-source community, particularly [LinuxServer.io](https://linuxserver.io) and [k8s-at-home](https://k8s-at-home.com/).

Each container definition in DockServer is specifically customized with:
- Standardized UID/GID mapping (`1000:1000`) for host filesystem permission parity.
- Integrated Traefik v3 reverse proxy labels and middleware routing rules.
- Pre-configured Authelia ForwardAuth security and mobile/API bypass endpoints.
- Common network bridge attachments (`traefik_proxy`).

---

## 🔄 Automated CI/CD & Security Audits

DockServer container images are maintained through an automated continuous integration and delivery (CI/CD) pipeline:
- **Dependency Tracking**: Upstream application releases and library updates are tracked and built automatically.
- **Security Audits**: Automated vulnerability scanning checks base images and dependencies for known CVEs.
- **Reproducible Builds**: All Dockerfiles and configurations are verified in isolated runner environments before being published.

---

## 📂 Standard Filesystem Layout

All containers deployed through DockServer adhere to a uniform host directory structure:

| Host Path | Purpose |
| :--- | :--- |
| `/opt/appdata/<app_name>/` | Persistent app data, configuration files, and SQLite databases |
| `/opt/appdata/compose/apps/<app_name>/` | Persistent `docker-compose.yml` service definitions |
| `/mnt/downloads/` | Default download target for torrent and Usenet clients |
| `/mnt/unionfs/` | Unified media mount point (when cloud storage mounts are active) |

---

## 🛠️ Container Operations

You can manage all DockServer containers using standard Docker commands:

```bash
# View active containers
docker ps

# Stream logs for a container
docker logs -f <app_name>

# Restart a specific service
docker restart <app_name>

# Update gateway containers
dockserver -u
```
