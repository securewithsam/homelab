# Pangolin + CrowdSec Setup Guide on Azure Ubuntu VPS

> Complete installation and configuration guide for Pangolin (Community Edition) with CrowdSec security integration on a fresh Azure Ubuntu VPS.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Phase 1 - Azure Configuration](#phase-1---azure-configuration)
4. [Phase 2 - Install Pangolin](#phase-2---install-pangolin)
5. [Phase 3 - Docker Compose Configuration](#phase-3---docker-compose-configuration)
6. [Phase 4 - CrowdSec Configuration](#phase-4---crowdsec-configuration)
7. [Phase 5 - Host Firewall Bouncer](#phase-5---host-firewall-bouncer)
8. [Phase 6 - Log Acquisition](#phase-6---log-acquisition)
9. [Verification](#verification)
10. [Docker User Permissions](#docker-user-permissions)
11. [Final Stack Summary](#final-stack-summary)

---

## Architecture Overview

| Container | Image | Role |
|-----------|-------|------|
| `pangolin` | `fosrl/pangolin:ee-1.16.2` | Dashboard & tunnel management |
| `gerbil` | `fosrl/gerbil:1.3.0` | WireGuard tunnel server |
| `traefik` | `traefik:v3.6` | Reverse proxy + SSL (Let's Encrypt) |
| `crowdsec` | `crowdsecurity/crowdsec:latest` | Threat detection engine |

**Bouncers (host-level agents):**
- `traefik-bouncer` — blocks bad IPs at the web/HTTP layer
- `vps-firewall` (crowdsec-firewall-bouncer-iptables) — blocks bad IPs at OS/SSH layer

---

## Prerequisites

- Fresh **Azure Ubuntu 22.04+** VPS with public IP
- A **domain name** you control
- SSH access with a sudo user
- Docker & Docker Compose (installed by Pangolin installer)

---

## Phase 1 - Azure Configuration

### 1.1 Open ports in Azure Network Security Group

In the Azure Portal: **VM → Networking → Add inbound port rule**

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH |
| 80 | TCP | HTTP / Let's Encrypt challenges |
| 443 | TCP | HTTPS |
| 51820 | UDP | WireGuard (Gerbil server) |
| 21820 | UDP | WireGuard (Newt clients) |

### 1.2 Configure UFW on the VPS

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 51820/udp
sudo ufw allow 21820/udp
sudo ufw enable
sudo ufw status
```

### 1.3 Set up DNS records

Get your VPS public IP:

```bash
curl ip.me
```

At your DNS registrar, create two A records pointing to your VPS IP:

| Type | Name | Value |
|------|------|-------|
| A | `pangolin` (or your chosen subdomain) | `<your-vps-ip>` |
| A | `*` (wildcard) | `<your-vps-ip>` |

The wildcard record allows Pangolin to dynamically create subdomains for each resource you expose.

Verify DNS propagation before proceeding:

```bash
dig pangolin.yourdomain.com
```

---

## Phase 2 - Install Pangolin

### 2.1 Download the installer

```bash
curl -fsSL https://static.pangolin.net/get-installer.sh | bash
```

### 2.2 Move installer and run

```bash
mkdir -p ~/pangolin
mv ./installer ~/pangolin/
cd ~/pangolin
sudo ./installer
```

### 2.3 Installer prompts — recommended answers

| Prompt | Answer |
|--------|--------|
| Edition | Community Edition |
| Base Domain | `yourdomain.com` (no subdomain) |
| Dashboard Domain | `pangolin.yourdomain.com` (default) |
| Let's Encrypt Email | Your email address |
| Install Gerbil (tunneling) | **Yes** |
| SMTP email | No (can add later) |
| Install CrowdSec | **Yes** |

The installer pulls Docker images and starts all containers. Takes 2–3 minutes.

### 2.4 Complete initial setup

Visit the URL shown at the end of installation:

```
https://pangolin.yourdomain.com/auth/initial-setup
```

- Create your admin account
- Create your first organization

> If SSL isn't ready immediately, wait a few minutes and try an incognito window.

---

## Phase 3 - Docker Compose Configuration

The Pangolin installer creates `~/docker-compose.yml`. The CrowdSec service was modified from the default to include additional security hardening.

### Full `docker-compose.yml` (with modifications) add only the ones with # commented

```yaml
networks:
  default:
    driver: bridge
    name: pangolin

services:
  crowdsec:
    container_name: crowdsec
    environment:
      COLLECTIONS: crowdsecurity/traefik crowdsecurity/appsec-virtual-patching crowdsecurity/appsec-generic-rules crowdsecurity/linux
      ENROLL_INSTANCE_NAME: pangolin-crowdsec
      ENROLL_TAGS: docker
      GID: "1000"
      PARSERS: crowdsecurity/whitelists
    healthcheck:
      interval: 10s
      retries: 3
      start_period: 30s
      test:
        - CMD
        - cscli
        - lapi
        - status
      timeout: 5s
    image: docker.io/crowdsecurity/crowdsec:latest
    labels:
      - traefik.enable=false
    ports:
      - 6060:6060                  # Metrics
      - 127.0.0.1:8080:8080        # Local API — localhost only, not public
    restart: unless-stopped
    volumes:
      - ./config/crowdsec:/etc/crowdsec
      - ./config/crowdsec/db:/var/lib/crowdsec/data
      - ./config/traefik/logs:/var/log/traefik:ro
      - /var/log/auth.log:/var/log/auth.log:ro   # SSH auth logs
      - /var/log/syslog:/var/log/syslog:ro        # System logs
    networks:
      - default
```

### Key changes from default

| Change | Reason |
|--------|--------|
| Removed `command: -t` | `-t` is test-only mode; causes container to exit after config validation |
| Added `127.0.0.1:8080:8080` | Exposes Local API for host firewall bouncer, bound to localhost only |
| Added `/var/log/auth.log` volume | Lets CrowdSec detect SSH brute force attempts |
| Added `/var/log/syslog` volume | Broader system log monitoring |
| Added `crowdsecurity/linux` collection | Enables Linux/SSH threat detection rules |

Apply changes:

```bash
cd ~
docker compose down
docker compose up -d
docker compose ps
```

---

## Phase 4 - CrowdSec Configuration

### 4.1 Fix directory ownership

The Pangolin installer may create config dirs as root. Fix ownership:

```bash
sudo chown -R infra-admin:infra-admin ~/config/crowdsec/acquis.d
```

> Replace `infra-admin` with your actual username.

---

## Phase 5 - Host Firewall Bouncer

This extends CrowdSec protection beyond Traefik to the OS level (SSH, iptables).

### 5.1 Install CrowdSec repositories and bouncer

```bash
curl -s https://install.crowdsec.net | sudo sh
sudo apt install -y crowdsec-firewall-bouncer-iptables
```

### 5.2 Generate API key

```bash
docker exec -it crowdsec cscli bouncers add vps-firewall
```

> **Copy the API key immediately** — it is only shown once.

### 5.3 Configure the bouncer

```bash
sudo nano /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
```

Update these two lines:

```yaml
api_url: http://127.0.0.1:8080
api_key: <PASTE_KEY_HERE>
```

### 5.4 Enable and start the bouncer

```bash
sudo systemctl enable crowdsec-firewall-bouncer
sudo systemctl restart crowdsec-firewall-bouncer
sudo systemctl status crowdsec-firewall-bouncer
```

---

## Phase 6 - Log Acquisition

Tell CrowdSec which logs to monitor by creating acquisition config files.

### 6.1 Traefik log acquisition

```bash
cat > ~/config/crowdsec/acquis.d/traefik.yaml << 'EOF'
filenames:
  - /var/log/traefik/*.log
labels:
  type: traefik
EOF
```

### 6.2 Syslog / SSH log acquisition

```bash
cat > ~/config/crowdsec/acquis.d/syslog.yaml << 'EOF'
filenames:
  - /var/log/auth.log
  - /var/log/syslog
labels:
  type: syslog
EOF
```

### 6.3 Restart CrowdSec to apply

```bash
docker compose restart crowdsec
```

### 6.4 Verify files inside container

```bash
docker exec crowdsec ls /etc/crowdsec/acquis.d/
# Expected output: appsec.yaml  syslog.yaml  traefik.yaml
```

---

## Verification

### Check all containers are running

```bash
docker compose ps
```

Expected output — all should show `Up` and `healthy`:

```
NAME       IMAGE                                     STATUS
crowdsec   crowdsecurity/crowdsec:latest             Up (healthy)
gerbil     fosrl/gerbil:1.3.0                        Up
pangolin   fosrl/pangolin:ee-1.16.2                  Up (healthy)
traefik    traefik:v3.6                              Up
```

### Check both bouncers are connected

```bash
docker exec crowdsec cscli bouncers list
```

Expected output:

```
 Name             IP Address  Valid  Last API pull         Type
 traefik-bouncer  172.18.0.x  ✔️     <timestamp>           Crowdsec-Bouncer-Traefik-Plugin
 vps-firewall     172.18.0.1  ✔️     <timestamp>           crowdsec-firewall-bouncer
```

Both showing `✔️` confirms the full protection chain is active.

### Check CrowdSec metrics

```bash
docker exec crowdsec cscli metrics
```

### Optional smoke test

> ⚠️ **Never ban your own IP.** Use a different IP (e.g. mobile hotspot) for testing.

```bash
# Add a 1-minute test ban
docker exec crowdsec cscli decisions add --ip <TEST_IP> -d 1m --type ban

# Remove it after testing
docker exec crowdsec cscli decisions delete --ip <TEST_IP>
```

---

## Docker User Permissions

To run `docker` commands without `sudo`:

```bash
sudo usermod -aG docker $USER
```

Then log out and back in:

```bash
exit
# SSH back in
ssh infra-admin@<your-vps-ip>

# Verify
docker ps
```

---

## Final Stack Summary

| Layer | Component | Status |
|-------|-----------|--------|
| Tunnel | Gerbil (WireGuard) | ✅ Ports 51820, 21820 UDP |
| Proxy | Traefik v3.6 | ✅ Ports 80, 443 TCP |
| Dashboard | Pangolin EE | ✅ `https://pangolin.yourdomain.com` |
| IDS | CrowdSec | ✅ Monitoring Traefik + SSH logs |
| Web bouncer | Traefik Plugin | ✅ Blocks malicious IPs at HTTP layer |
| Host bouncer | IPTables Firewall | ✅ Blocks malicious IPs at OS layer |

---

## Next Steps

- **Enroll in CrowdSec Console** at [app.crowdsec.net](https://app.crowdsec.net) for access to the community blocklist (millions of known bad IPs)
- **Enable 2FA** on your Pangolin admin account
- **Add your first Site** in Pangolin dashboard and install the Newt client on your home server
- **Add Resources** to expose self-hosted services through the tunnel

---

## References

- [Pangolin Docs - Quick Install](https://docs.pangolin.net/self-host/quick-install)
- [Pangolin Docs - CrowdSec](https://docs.pangolin.net/self-host/community-guides/crowdsec)
- [CrowdSec Firewall Bouncer Docs](https://docs.crowdsec.net/u/bouncers/firewall/)
- [CrowdSec Bouncer Traefik Plugin](https://plugins.traefik.io/plugins/6335346ca4caa9ddeffda116/crowdsec-bouncer-traefik-plugin)
