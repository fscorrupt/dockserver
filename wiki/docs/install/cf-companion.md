# Cloudflare Companion (CF-Companion)

[Cloudflare Companion](https://github.com/tiredofit/docker-traefik-cloudflare-companion) is an automated DNS helper running alongside Traefik in DockServer.

---

## What Does It Do?

Whenever you deploy a new container in DockServer (such as Radarr, Sonarr, or Jellyfin), CF-Companion detects Traefik's host labels and **automatically creates a DNS CNAME record** in your Cloudflare account.

- **Zero Manual DNS Management**: You never need to manually add DNS records for individual subdomains in Cloudflare.
- **Instant Routing**: As soon as an app finishes deploying, `radarr.yourdomain.com`, `sonarr.yourdomain.com`, etc., resolve instantly.
- **Automatic Cleanup**: If a container is removed, CF-Companion automatically cleans up the stale DNS record.

---

## How It Works

1. You install an application in DockServer (via `dockserver -i` or `dockserver -a <app>`).
2. The application's `docker-compose.yml` includes Traefik router rules (e.g. `Host(\`radarr.${DOMAIN}\`)`).
3. CF-Companion detects this rule through Docker's event stream.
4. It calls Cloudflare's API and creates a CNAME pointing `radarr.yourdomain.com` to your root domain `yourdomain.com`.

---

## Verification

To check if CF-Companion is running and actively managing your records:

```bash
docker logs -f cf-companion
```

You will see logs detailing any detected containers and newly registered Cloudflare CNAME records.
