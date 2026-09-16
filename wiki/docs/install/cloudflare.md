# Cloudflare Configuration

DockServer integrates tightly with [Cloudflare](https://www.cloudflare.com/) for automated DNS management, DDoS protection, and wildcard SSL certificates.

---

## Why Cloudflare?

- **Automated Wildcard SSL Certificates**: Traefik uses Cloudflare DNS challenge (`dns-cloudflare`) to automatically request and renew Let's Encrypt certificates for `*.yourdomain.com`.
- **Automatic Subdomain Creation**: With CF-Companion, every application you deploy instantly gets an automated DNS CNAME record in Cloudflare without manual intervention.
- **Edge Protection & Fast CDN**: Cloudflare provides global CDN caching, DDoS mitigation, and HTTP/3 support.

---

## 3-Step Setup Guide

### 1. Add an A-Record for Your Server
1. Log into your [Cloudflare Dashboard](https://dash.cloudflare.com/) and select your domain.
2. Navigate to **DNS** > **Records**.
3. Click **Add Record**:
   - **Type**: `A`
   - **Name**: `@` (or your domain name)
   - **IPv4 address**: Your server's public IP address
   - **Proxy status**: Proxied (Orange cloud) or DNS only (Grey cloud)
   - **TTL**: Auto
4. Click **Save**.

### 2. Configure SSL/TLS Settings
1. Navigate to **SSL/TLS** in the left menu.
2. Under **Overview**, set the encryption mode to **Full**.
   > **Note**: Do not set this to "Full (Strict)" before running DockServer for the first time, as Let's Encrypt certificates need to be generated first.
3. Under **Edge Certificates**:
   - Enable **Always Use HTTPS** (Turns all HTTP requests into HTTPS).
   - Set **Minimum TLS Version** to **TLS 1.2**.
   - Enable **TLS 1.3**.
4. (Optional) Under **Speed** > **Optimization**, enable **Brotli** and **Early Hints**.
5. (Optional) Under **Network**, ensure **WebSockets** and **gRPC** are toggled **ON**.

### 3. Retrieve Your API Credentials
DockServer requires your Cloudflare credentials to automate SSL certificate issuance and DNS record creation:

1. **Cloudflare Email**: The email address you use to sign into Cloudflare.
2. **Global API Key**:
   - Click your profile icon in the top-right corner > **My Profile**.
   - Click **API Tokens** in the left menu.
   - Under **API Keys**, find **Global API Key** and click **View**.
   - Enter your password to view and copy your API key.
3. **Zone ID**:
   - Return to your domain's dashboard.
   - On the **Overview** page, scroll down the right sidebar until you see **API** > **Zone ID**.
   - Click to copy the Zone ID string.

---

## Entering Credentials into DockServer

When running `sudo dockserver -i` and selecting `[ 1 ] Edge Gateway`:
- Enter your **Domain** (e.g. `example.com`)
- Enter your **Cloudflare Email**
- Paste your **Global API Key**
- Paste your **Zone ID**

The gateway will automatically configure Traefik v3 and Cloudflare Companion with these credentials!
