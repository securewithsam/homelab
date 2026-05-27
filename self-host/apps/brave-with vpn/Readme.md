# Geo-Testing Browser Stack

Isolated Brave browser instances exiting through different VPN geolocations for testing websites from various regions. Built with [Gluetun](https://github.com/qdm12/gluetun) (VPN container) and [LinuxServer Brave](https://docs.linuxserver.io/images/docker-brave/) (browser-in-browser via KasmVNC).

## Why This Exists

If a team needs to test the website from different geographic locations (provinces, countries) to verify geo-targeted content, regional pricing, CDN behavior, and localization. Corporate policy blocks third-party VPN clients on endpoints, so this stack provides isolated browser sessions that exit through Surfshark VPN — accessible from any browser on the corporate network with zero client-side software.

## Architecture

```
User's browser (any device on the network)
  │
  ▼ HTTPS (KasmVNC)
┌──────────────────────────────────────────┐
│  Docker Host (DMZ / Lab VM)              │
│                                          │
│  :4001 → [Brave] → [Gluetun] → Vancouver│
│  :4002 → [Brave] → [Gluetun] → London   │
│  :4003 → [Brave] → [Gluetun] → Mumbai   │
│  :4004 → [Brave] → [Gluetun] → New York │
│  :4005 → [Brave] → [Gluetun] → Hong Kong│
└──────────────────────────────────────────┘
```

Each geo runs two containers:

1. **Gluetun** — lightweight VPN client with native Surfshark support (WireGuard)
2. **Brave** — full Brave browser streamed to your browser via KasmVNC, all traffic routed through Gluetun's VPN tunnel

## Port Map

| Port | Geo | VPN Exit |
|------|-----|----------|
| 4001 | Canada - BC | Vancouver |
| 4002 | United Kingdom | London |
| 4003 | India | Mumbai |
| 4004 | United States | New York |
| 4005 | Hong Kong | Hong Kong |

## Prerequisites

- Docker Engine 24+ with Compose v2
- Surfshark account with WireGuard manual setup credentials
- Host with 8+ GB RAM (each Brave instance uses ~1-1.5 GB)
- Network access to Surfshark WireGuard endpoints (UDP 51820 outbound)

## Quick Start

### 1. Clone the repo

```bash
git clone <repo-url>
cd brave-geo
```

### 2. Configure

Edit `docker-compose.yml` and replace the following placeholders:

- `YOUR_KEY_HERE` — your Surfshark WireGuard private key (same key for all geos)
- `your-secure-password` — password for the Brave browser sessions

**Where to find your WireGuard private key:**

Surfshark Dashboard → Manual Setup → WireGuard → generate a keypair → copy the private key.

### 3. Open firewall ports

```bash
sudo ufw allow in 4001:4005/tcp
```

If your host has restrictive outbound/routing rules:

```bash
sudo ufw allow out 51820/udp
sudo ufw default allow routed
sudo ufw reload
```

### 4. Launch

```bash
docker compose up -d
```

### 5. Verify

Check all VPN tunnels are healthy:

```bash
docker compose ps
docker compose logs gluetun-bc
docker compose logs gluetun-uk
```

Look for `INFO [vpn] Public IP is X.X.X.X` in each gluetun log — that confirms the tunnel is up and shows the exit IP.

### 6. Access

Open your browser and navigate to:

```
https://<host-ip>:4001    # Vancouver
https://<host-ip>:4002    # London
https://<host-ip>:4003    # Mumbai
https://<host-ip>:4004    # New York
https://<host-ip>:4005    # Hong Kong
```

Accept the self-signed certificate warning. Log in with username `swsadmin` and your configured password.

To verify the exit location, visit `ifconfig.me` or `whatismyipaddress.com` inside the Brave browser.

## Adding a New Geo

Add a gluetun + brave pair to `docker-compose.yml`:

```yaml
  gluetun-xx:
    image: qmcgaw/gluetun:latest
    container_name: gluetun-xx
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    environment:
      - VPN_SERVICE_PROVIDER=surfshark
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=YOUR_KEY_HERE
      - WIREGUARD_ADDRESSES=10.14.0.2/16
      - SERVER_COUNTRIES=CountryName
      - SERVER_CITIES=CityName
      - TZ=America/Toronto
    ports:
      - "400X:3001"

  brave-xx:
    image: lscr.io/linuxserver/brave:latest
    container_name: brave-xx
    restart: unless-stopped
    network_mode: "service:gluetun-xx"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Toronto
      - CUSTOM_USER=swsadmin
      - PASSWORD=your-secure-password
    volumes:
      - brave-xx-data:/config
    shm_size: "1gb"
```

Add `brave-xx-data:` under the `volumes:` section at the bottom.

Available Surfshark locations can be found in the [Gluetun Surfshark wiki](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/surfshark.md).

## Operations

| Task | Command |
|------|---------|
| Start all | `docker compose up -d` |
| Stop all | `docker compose down` |
| Restart a geo | `docker compose restart gluetun-uk brave-uk` |
| View logs | `docker compose logs -f gluetun-bc` |
| Check status | `docker compose ps` |
| Update images | `docker compose pull && docker compose up -d` |
| Wipe browser data | `docker compose down -v` |

## Troubleshooting

**Gluetun exits with "Wireguard settings: interface address is not set"**
Add `WIREGUARD_ADDRESSES=10.14.0.2/16` to the gluetun environment variables.

**Gluetun can't connect (no public IP logged)**
Check that UDP 51820 outbound is allowed from the host. If using UFW with `deny (routed)`, run `sudo ufw default allow routed && sudo ufw reload`.

**Brave shows a black screen or won't load**
Increase `shm_size` to `2gb`. Chrome-based browsers need shared memory for rendering.

**"This site can't be reached" inside Brave**
The VPN tunnel isn't up yet. Check `docker compose logs gluetun-xx` for errors. The brave container shares gluetun's network stack — no tunnel means no internet.

**Self-signed certificate warning**
Expected behavior. KasmVNC uses a self-signed cert by default. Accept the warning or place a real cert behind a reverse proxy.

## Security Notes

- WireGuard private keys are in `docker-compose.yml` — do not commit this file with real keys. Use environment variables or Docker secrets in production.
- KasmVNC password is a shared secret — rotate periodically.
- For production/DMZ deployment, place behind a reverse proxy (Cloudflare Tunnel, Nginx, Pangolin) with proper authentication (SSO via Entra ID recommended).
- Each Brave instance persists data in a Docker volume. Run `docker compose down -v` to wipe all browser data.
- Browser sessions are isolated per geo — cookies, cache, and history do not cross between instances.

## Stack

| Component | Purpose | License |
|-----------|---------|---------|
| [Gluetun](https://github.com/qdm12/gluetun) | VPN client container | MIT |
| [Brave (LinuxServer)](https://docs.linuxserver.io/images/docker-brave/) | Browser-in-browser | GPL-3.0 |
| [Surfshark](https://surfshark.com) | VPN provider (WireGuard) | Commercial subscription |
