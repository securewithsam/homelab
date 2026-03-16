


###  BUILD FROM SCRATCH (ROOT MODE)

---

## Create folder structure

```bash
mkdir -p /root/docker/vaultwarden/vw-data
cd /root/docker/vaultwarden
```

Set ownership (intentionally root):

```bash
chown -R root:root /root/docker
chmod -R 750 /root/docker
```

---

## Create docker-compose.yml

```bash
nano /root/docker/vaultwarden/docker-compose.yml
```


Optional Email Environment Variables
```yaml
  SMTP_HOST: "smtp.gmail.com"
  SMTP_FROM: "vault@gmail.com"
  SMTP_FROM_NAME: "Vaultwarden"
  SMTP_USERNAME: "yourgmail@gmail.com"
  SMTP_PASSWORD: "GMAIL_APP_PASSWORD"
  SMTP_PORT: "587"
  SMTP_SECURITY: "starttls"
```
Save and exit.

---

## Start Vaultwarden (clean first boot)

```bash
docker compose pull
docker compose up -d
```

Confirm:

```bash
docker ps --filter name=vaultwarden
```

---

## Verify DB creation (sanity check)

```bash
ls -l /root/docker/vaultwarden/vw-data
```

You should see:

```
db.sqlite3
rsa_key.pem
tmp/
```

Owned by `root:root` ✅

---



## Test flow

1. Open (incognito):

   ```
   https://vault.sws.com
   ```
2. Click **Create Account**
3. Use:

   ```
   you@sws.com
   ```
4. Registration succeeds
5. Login works immediately


---

# Hardening (recommended)

After first user is created:

### Disable signups completely

```yaml
SIGNUPS_ALLOWED: "false"
```

Restart:

```bash
docker compose down
docker compose up -d
```

