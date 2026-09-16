# CrowdSec Intrusion Prevention System (IPS)

DockServer integrates **[CrowdSec](https://www.crowdsec.net/)** to provide automated, collaborative security for your server and all exposed web applications.

---

## 🛡️ How It Protects You

CrowdSec acts as an intelligent security layer at your Traefik reverse proxy gateway:

1. **Traffic Analysis**: It continuously analyzes Traefik's JSON access logs to identify attacks (brute-force login attempts, port scans, SQL injections, and known CVE exploits).
2. **Instant Gateway Bouncing**: The `crowdsec-bouncer-traefik-plugin` checks incoming requests against an in-memory cache of banned IPs and drops malicious connections in microseconds.
3. **Global Threat Feeds**: DockServer automatically subscribes CrowdSec to 28+ global threat intelligence feeds (including Abuse.ch, Spamhaus, and IPsum) to block known malicious bots before they ever touch your server.

---

## 🔒 Automated Whitelisting (No Lockouts)

DockServer includes automated protections so you never accidentally lock yourself out:

- **Server External IP Whitelist**: During deployment (`dockserver -i`) or migration (`dockserver -m`), DockServer automatically detects your host's public IP and adds it to the CrowdSec whitelist (`/opt/appdata/crowdsec/config/postoverflows/s01-whitelist/static-whitelist.yaml`).
- **Private LAN Ranges**: All RFC 1918 private subnets (`192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`) and loopback addresses (`127.0.0.1`, `::1`) are permanently whitelisted.

---

## 📋 Common CrowdSec Commands

You can interact with CrowdSec at any time using the `cscli` tool inside the container:

### Check Active Bans & Decisions
```bash
docker exec -t crowdsec cscli decisions list
```

### View Recent Security Alerts
```bash
docker exec -t crowdsec cscli alerts list
```

### Check Registered Bouncers
```bash
docker exec -t crowdsec cscli bouncers list
```
*(You will see `traefik-bouncer` and `blocklist-import` in active status)*

### Manually Ban an IP
```bash
docker exec -t crowdsec cscli decisions add --ip 198.51.100.1 --duration 24h --reason "Manual ban"
```

### Unban an IP
```bash
docker exec -t crowdsec cscli decisions delete --ip 198.51.100.1
```

### View Metrics & Detection Stats
```bash
docker exec -t crowdsec cscli metrics
```
