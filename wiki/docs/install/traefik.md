# Traefik v3 Reverse Proxy

DockServer uses **[Traefik v3](https://traefik.io/traefik/)** as its edge reverse proxy and ingress gateway. Traefik automatically manages SSL certificates, routes incoming requests to the appropriate Docker containers, and applies security middleware.

---

## 🌟 Key Features

- **Automated Wildcard SSL Certificates**: Integrates with Cloudflare via Let's Encrypt DNS-01 challenge (`*.yourdomain.com`).
- **HTTP/3 & QUIC**: High-speed, modern protocol support enabled out-of-the-box.
- **Cloudflare Real IP Support**: Automatically trusts Cloudflare proxy IPs and extracts visitor IPs via `CF-Connecting-IP`.
- **Integrated Security Middleware**:
  - **CrowdSec IPS Bouncer**: Drops threats before reaching your containers.
  - **Authelia ForwardAuth**: Protects private services behind Single Sign-On and 2FA.
  - **Rate Limiting & Security Headers**: Shields against abuse and enforces modern web security standards.
  - **Branded Error Pages**: Graceful handling for HTTP 404, 500, and 502 error codes.

---

## 🌐 Accessing Gateway Dashboards

Once deployed, access your management dashboards in any web browser:

| Dashboard | URL | Authentication |
| :--- | :--- | :--- |
| **Traefik Control Panel** | `https://traefik.yourdomain.com` | Protected by Authelia |
| **Real-time Log Dashboard** | `https://traefik-dashboard.yourdomain.com` | Protected by Authelia |
| **Authelia SSO Portal** | `https://authelia.yourdomain.com` | Direct Login |

---

## 📁 Traefik File Locations

All Traefik files and certificates live under `/opt/appdata/traefik/`:

- `/opt/appdata/traefik/acme/acme.json`: Your Let's Encrypt wildcard certificates (stored securely with `600` permissions).
- `/opt/appdata/traefik/logs/access.log`: Real-time JSON access logs analyzed by CrowdSec and the Log Dashboard.
- `/opt/appdata/traefik/rules/`: Custom dynamic configuration, routers, and middleware chains.

---

## 🔧 Useful Commands

### View Live Traefik Logs
```bash
docker logs -f traefik
```

### Check Generated Certificates
Verify that wildcard certificates were generated for your domain:
```bash
sudo cat /opt/appdata/traefik/acme/acme.json | grep -i "yourdomain.com"
```

### Restart Traefik
```bash
docker compose -f /opt/appdata/compose/docker-compose.yml restart traefik
```
