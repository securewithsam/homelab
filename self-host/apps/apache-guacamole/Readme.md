

**One-time DB init before first run:**
```bash
mkdir -p ./init
docker run --rm guacamole/guacamole:latest \
  /opt/guacamole/bin/initdb.sh --mysql > ./init/initdb.sql
```

**Then bring it up:**
```bash
docker compose up -d
```

Access at `http://your-host:8080` — default login is `guacadmin` / `guacadmin`, change it immediately.

For SSL in your homelab, just put Nginx Proxy Manager or Traefik in front of it — point it at port 8080 and let the proxy handle TLS. That's cleaner than bundling NGINX into the stack anyway.
