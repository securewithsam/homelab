# VPS + Docker + Cloudflare Tunnel + OpenClaw + Open WebUI

```
Browser → Cloudflare → Tunnel → Open WebUI → OpenClaw → LLM provider
```

---

## 1. Docker

```bash
sudo apt update && sudo apt upgrade -y
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

---

## 2. Folder structure

```bash
mkdir -p ~/ai-stack
mkdir -p ~/openclaw-data/workspace
mkdir -p ~/open-webui-data
cd ~/ai-stack
```

---

## 3. Docker Compose

```bash
nano docker-compose.yml
```

Replace `YOUR_USERNAME` with your username (find it with: `whoami`).
Generate a secret key: `openssl rand -hex 32`

```yaml
services:
  openclaw:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    tty: true
    stdin_open: true
    volumes:
      - /home/YOUR_USERNAME/openclaw-data:/home/node/.openclaw
      - /home/YOUR_USERNAME/openclaw-data/workspace:/home/node/.openclaw/workspace
    ports:
      - "127.0.0.1:18789:18789"
    networks:
      - ai-net

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    depends_on:
      - openclaw
    volumes:
      - /home/YOUR_USERNAME/open-webui-data:/app/backend/data
    environment:
      - OPENAI_API_KEY=dummy
      - OLLAMA_BASE_URL=
      - ENABLE_OLLAMA_API=false
      - WEBUI_SECRET_KEY=paste_openssl_output_here
    ports:
      - "127.0.0.1:3000:8080"
    networks:
      - ai-net

networks:
  ai-net:
    driver: bridge
```

---

## 4. Start containers

```bash
docker compose up -d
```

Check logs:

```bash
docker compose logs -f
```

**Good:**
- `openclaw` — `Listening on port 18789` or `Server started`
- `open-webui` — `Application startup complete` or `Uvicorn running`

**Bad:**
- `Error`, `Exception`, `Connection refused`, `Exit code 1`

Exit log view: `Ctrl+C` — containers keep running.

---

## 5. Enable OpenAI-compatible API in OpenClaw

By default `/v1/models` requires a token and an enabled endpoint. First generate a token:

```bash
openssl rand -hex 24
```

Copy the output — that's your token. Edit the config:

```bash
nano ~/openclaw-data/openclaw.json
```

Add the `http` section inside `gateway`:

```json
{
  "gateway": {
    "auth": {
      "mode": "token",
      "token": "paste_openssl_output_here"
    },
    "controlUi": {
      "allowedOrigins": [
        "http://localhost:18789",
        "http://127.0.0.1:18789"
      ]
    },
    "http": {
      "endpoints": {
        "chatCompletions": {
          "enabled": true
        }
      }
    }
  }
}
```

Restart the container:

```bash
docker restart openclaw
```

Verify the API works:

```bash
curl http://127.0.0.1:18789/v1/models -H "Authorization: Bearer your_token_here"
```

Should return JSON with models `openclaw`, `openclaw/default`, `openclaw/main`.

> Token is stored in `~/openclaw-data/openclaw.json` → `gateway.auth.token`

---

## 6. Cloudflare Tunnel

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) → **Zero Trust** → **Networks** → **Tunnels** → **Create a tunnel**
2. Name the tunnel, select **Debian + 64-bit**
3. Copy the **Install as service** command:
   ```bash
   sudo cloudflared service install eyJh...
   ```
4. Run on the VPS:
   ```bash
   sudo cloudflared service install eyJh...
   sudo systemctl start cloudflared
   sudo systemctl status cloudflared
   ```
5. Go back to the dashboard → tunnel → **Hostname routes** → **Add a public hostname**:
   - Subdomain: `chat`
   - Domain: `yourdomain.com`
   - Service Type: `HTTP`
   - URL: `localhost:3000`

> If you get "record already exists" when adding the hostname — go to **DNS** and delete the old record manually.
> The DNS record must be **Proxied** (orange cloud) — otherwise the tunnel won't work.

---

## 7. First login to WebUI

Open `https://chat.yourdomain.com` — create an account. The first user gets admin rights.

---

## 8. Connect OpenClaw to WebUI

**Admin Settings → Connections → Manage OpenAI API Connections → gear icon**

| Field   | Value                      |
|---------|----------------------------|
| URL     | `http://openclaw:18789/v1` |
| Auth    | Bearer                     |
| API Key | token from `openclaw.json` |

Save — models `openclaw`, `openclaw/default`, `openclaw/main` will appear in the dropdown.

---

## 9. Authorize a provider

### Option A — OpenAI API key (recommended)

Get an API key at [platform.openai.com](https://platform.openai.com) → API keys → Create new secret key.

Enter the container and run the wizard:

```bash
docker exec -it openclaw bash
openclaw configure
```

Select **Model** → **OpenAI** → **API key** → paste the key.

The wizard writes the config in the correct format — no need to edit `openclaw.json` manually.

Exit the container and restart:

```bash
exit
docker restart openclaw
```

OpenAI models will appear in the WebUI dropdown — select one and start chatting.

### Option B — OAuth (Codex)

```bash
docker exec -it openclaw bash
openclaw models auth login
```

Select the provider, open the OAuth URL in your browser, log in, paste the callback URL back into the terminal.

> ⚠️ **Known bug in OpenClaw 2026.4.x:** OAuth with OpenAI Codex does not request the `model.request` scope — requests fail with `401 Missing scopes`. Issue is open, no fix yet.
> If the account has no balance on platform.openai.com — `exceeded quota` error.

---

## 10. Check after reboot

```bash
sudo reboot
```

After rebooting:

```bash
cd ~/ai-stack
docker ps
systemctl status cloudflared
docker compose logs -f
```

All three should be running.

---

## Summary

```
Browser → Cloudflare Tunnel → Open WebUI → OpenClaw → LLM provider
```

**What's guaranteed:**
- Nothing exposed externally — everything on `127.0.0.1`
- Data persists in volumes across reboots
- All services start automatically

---

## 11. Signal integration

OpenClaw connects to Signal through an external daemon called `signal-cli`. You need a dedicated phone number for the bot — using your personal number causes a reply loop.

### Install signal-cli

Java 21 or later is required.

```bash
sudo apt install openjdk-21-jre -y
```

Download the latest signal-cli:

```bash
VERSION=$(curl -s https://api.github.com/repos/AsamK/signal-cli/releases/latest | grep tag_name | cut -d'"' -f4 | sed 's/v//')
curl -L "https://github.com/AsamK/signal-cli/releases/download/v${VERSION}/signal-cli-${VERSION}-Linux-native.tar.gz" -o /tmp/signal-cli.tar.gz
sudo tar xf /tmp/signal-cli.tar.gz -C /opt
sudo ln -sf /opt/signal-cli-${VERSION}/bin/signal-cli /usr/local/bin/signal-cli
signal-cli --version
```

### Link an account

**Option A — link existing account via QR (recommended):**

```bash
signal-cli link -n "OpenClaw"
```

The command outputs a link like `sgnl://linkdevice?...` — convert it to a QR code at [zxing.appspot.com](https://zxing.appspot.com/generator) and scan it from the Signal app on your phone (Settings → Linked Devices → Add).

**Option B — register a new number:**

```bash
signal-cli -a +1XXXXXXXXXX register
signal-cli -a +1XXXXXXXXXX verify CODE_FROM_SMS
```

### Configure OpenClaw

```bash
nano ~/openclaw-data/openclaw.json
```

Add the `channels` section alongside `gateway`:

```json
{
  "gateway": {
    ...
  },
  "channels": {
    "signal": {
      "enabled": true,
      "account": "+1XXXXXXXXXX",
      "cliPath": "signal-cli",
      "dmPolicy": "pairing",
      "allowFrom": ["+1XXXXXXXXXX_YOUR_PERSONAL_NUMBER"]
    }
  }
}
```

- `account` — the bot's phone number (registered with signal-cli)
- `allowFrom` — your personal number that is allowed to message the bot
- `dmPolicy: pairing` — first message requires approval

Restart the container:

```bash
docker restart openclaw
```

### First connection

Send a message to the bot from your phone via Signal. OpenClaw will output a pairing code — approve it on the VPS:

```bash
docker exec -it openclaw bash
openclaw pairing approve signal CODE
```

After that the bot will reply to messages in Signal.

### Verify

```bash
docker compose -f ~/ai-stack/docker-compose.yml logs -f openclaw | grep -i signal
```

---

## Mac mini differences

Everything else in the guide is the same — `docker-compose.yml`, OpenClaw config, WebUI settings, `openclaw configure`.

### Docker

Install via Docker Desktop instead of the install script:

```bash
brew install --cask docker
```

Or download from [docker.com](https://docker.com). After installing, launch Docker Desktop — it must be running for containers to work.

### Paths

Use `/Users/username/` instead of `/home/username/`:

```yaml
volumes:
  - /Users/YOUR_USERNAME/openclaw-data:/home/node/.openclaw
  - /Users/YOUR_USERNAME/openclaw-data/workspace:/home/node/.openclaw/workspace
```

```yaml
volumes:
  - /Users/YOUR_USERNAME/open-webui-data:/app/backend/data
```

### Cloudflare Tunnel

```bash
brew install cloudflared
```

Service installation — same command from the dashboard:

```bash
sudo cloudflared service install eyJh...
```

Auto-start uses launchd instead of systemd:

```bash
sudo launchctl start com.cloudflare.cloudflared
```

Check status:

```bash
sudo launchctl list | grep cloudflared
```

### signal-cli

No need to install Java separately:

```bash
brew install signal-cli
```

### Container auto-start

On Mac, Docker Desktop launches at login and automatically starts containers with `restart: unless-stopped`. No additional configuration needed.
