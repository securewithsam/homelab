# Beszel Agent — RackNerd Ubuntu VPS

Deploy a Beszel monitoring agent on a remote RackNerd Ubuntu VPS using Docker Compose, with an outbound encrypted connection to a self-hosted Beszel Hub published through Pangolin.

## Deployment overview

| Setting | Value |
|---|---|
| Beszel system name | `RN-VPS-UBU-PANG-TUN-01` |
| Hosting provider | RackNerd VPS |
| OS | Ubuntu Linux |
| VPS role | Pangolin tunnel server |
| Agent deployment | Docker Compose |
| Agent directory | `/root/beszel-agent` (as used in this deployment) |
| Beszel Hub | HomeLab server `10.0.100.51`, local host port `8109` |
| External Hub URL | `https://monitoring.sws.ca` |
| Connection | Agent-initiated outbound WebSocket over HTTPS (TCP 443) |
| Inbound agent port | None required |

**Traffic flow:** RackNerd Beszel Agent → HTTPS/WSS `monitoring.sws.ca:443` → Pangolin/Newt → Beszel Hub `10.0.100.51:8109`.

> Prerequisites: Docker Engine and the Docker Compose plugin are installed on the VPS, the Beszel Hub works via its Pangolin domain, and Pangolin permits the agent's WebSocket upgrade at `/api/beszel/agent-connect`. A Pangolin interactive-login challenge on this endpoint will break agent connectivity.

## 1. Register the VPS in the Beszel Hub

1. Sign in to the Beszel dashboard at `https://monitoring.sws.ca`.
2. Select **Add System** and choose **Docker Compose**.
3. Name the system `RN-VPS-UBU-PANG-TUN-01`.
4. Copy the generated **KEY** (public key) and **TOKEN** into a temporary secure location. Do not commit them to Git.
5. Use the outbound WebSocket connection method. The **Hub URL** is `https://monitoring.sws.ca` — **not** `http://monitoring.sws.ca:8109`.

For outbound WebSocket mode, the VPS's public IP is not needed for the Hub to connect to the agent.

## 2. Create the agent directory on RackNerd

Log into the VPS using your configured SSH port (in this deployment, TCP `20022`):

```bash
ssh -p 20022 root@YOUR_RACKNERD_PUBLIC_IP
```

Create the working directory:

```bash
mkdir -p /root/beszel-agent
cd /root/beszel-agent
```

## 3. Create the Docker Compose file

Create `docker-compose.yml`:

```bash
nano docker-compose.yml
```

Paste:

```yaml
name: beszel-agent

services:
  beszel-agent:
    image: henrygd/beszel-agent:latest
    container_name: beszel-agent
    restart: unless-stopped
    network_mode: host

    volumes:
      - ./beszel_agent_data:/var/lib/beszel-agent
      - /var/run/docker.sock:/var/run/docker.sock:ro

    environment:
      HUB_URL: https://monitoring.sws.ca
      KEY: ${BESZEL_KEY:?Set BESZEL_KEY in .env}
      TOKEN: ${BESZEL_TOKEN:?Set BESZEL_TOKEN in .env}
      DISABLE_SSH: "true"
```

Notes:
- `DISABLE_SSH=true` disables the agent's inbound SSH server. No agent listener needs to be exposed on TCP `45876`.
- `network_mode: host` supports host networking metrics.
- The Docker socket mount enables container monitoring. Even with `:ro`, Docker socket access is security-sensitive. Remove that mount if container monitoring is not needed.
- A specific, tested image tag or digest is preferable to `latest` for controlled updates.

## 4. Configure agent credentials

Create `.env` in the same directory:

```bash
umask 077
nano .env
```

Use the KEY and TOKEN from the Beszel **Add System** dialog:

```dotenv
BESZEL_KEY="PASTE_YOUR_BESZEL_PUBLIC_KEY"
BESZEL_TOKEN=PASTE_YOUR_BESZEL_TOKEN
```

Restrict permissions and prevent accidental Git commits:

```bash
chmod 600 .env
printf '.env\nbeszel_agent_data/\n' > .gitignore
```

Never publish the token or your resolved `docker compose config` output. If a real token has been exposed, rotate it in Beszel.

## 5. Verify outbound connectivity

```bash
curl -I https://monitoring.sws.ca
```

A valid HTTPS response confirms basic reachability; it does **not** prove WebSocket authentication. The Pangolin route must preserve the `/api/beszel/agent-connect` endpoint and support WebSocket upgrades.

## 6. Start the agent

```bash
cd /root/beszel-agent

docker compose config -q
docker compose pull
docker compose up -d
docker compose ps
```

Check logs:

```bash
docker compose logs --tail=50 beszel-agent
```

Successful connection typically appears as:

```text
INFO WebSocket connected host=monitoring.sws.ca
```

Confirm `RN-VPS-UBU-PANG-TUN-01` is shown as **Online** in the Beszel Hub and starts reporting CPU, memory, disk, network, and available container statistics.

## 7. UFW and network security

**Do not open any new inbound port for this agent.** The agent connects outbound to the Hub over HTTPS.

| Port | Direction at RackNerd VPS | Action |
|---|---|---|
| TCP 443 | Outbound to Beszel/Pangolin domain | Allow if egress is restricted |
| TCP 45876 | Inbound to Beszel agent | Keep closed (`DISABLE_SSH=true`) |
| TCP 8109 | Inbound to VPS | Not required |
| TCP 20022 | Inbound for VPS administration | Keep existing restricted SSH rule |
| TCP 80/443 | Inbound for Pangolin's existing service | Preserve existing rules |

View current firewall rules:

```bash
ufw status verbose
```

If UFW already allows outbound connections, no firewall changes are necessary. Do not reset UFW on the Pangolin VPS.

## 8. Common troubleshooting

| Symptom | Check |
|---|---|
| Agent shows Offline | `docker compose logs --tail=50 beszel-agent`; HTTPS access to Hub |
| `401 Unauthorized` | Verify agent TOKEN, KEY, and Beszel registration; check Pangolin auth challenges |
| WebSocket upgrade fails | Confirm Pangolin forwards WebSocket traffic to `/api/beszel/agent-connect` |
| HTTPS error | Confirm `HUB_URL=https://monitoring.sws.ca`, TLS certificate, and DNS |
| Container statistics missing | Confirm Docker socket mount and agent permissions |

Useful commands:

```bash
docker compose ps
docker compose logs --tail=100 beszel-agent
docker inspect beszel-agent --format '{{.State.Status}}'
```

## 9. Maintenance

Update only this Compose project:

```bash
cd /root/beszel-agent
docker compose pull
docker compose up -d
docker compose ps
```

Restart without deleting data:

```bash
docker compose restart beszel-agent
```

Stop the agent:

```bash
docker compose stop beszel-agent
```

**Do not run host-wide Docker cleanup commands** on this VPS; it also hosts Pangolin. Avoid `docker system prune --volumes`, mass container removal, and deleting agent data without a recovery plan.

## Official documentation

- [Beszel Agent Installation](https://beszel.dev/guide/agent-installation)
- [Beszel Environment Variables](https://beszel.dev/guide/environment-variables)
- [Beszel Security and Network Requirements](https://beszel.dev/guide/security)
- [Beszel Getting Started](https://beszel.dev/guide/getting-started)
