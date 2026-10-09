# DocuSeal — Docker Deployment

Self-hosted DocuSeal electronic signature platform deployed using Docker Compose, PostgreSQL 18, and Pangolin reverse proxy.

## Infrastructure

| Component | Configuration |
|---|---|
| Application | DocuSeal |
| Docker Host | Dell OptiPlex 7050 |
| Operating System | Ubuntu Linux |
| Database | PostgreSQL 18 |
| Reverse Proxy | Pangolin (separate server) |
| Application URL | https://docuseal.sws.ca |
| Internal IP | 10.0.100.51 |
| Host Port | 3005 |
| Container Port | 3000 |
| Installation Path | `/data/apps/docuseal` |

## 1. Create Application Directory

```bash
sudo mkdir -p /data/apps/docuseal
cd /data/apps/docuseal
```

## 2. Create Docker Compose File

```bash
sudo nano docker-compose.yml
```

Add the DocuSeal and PostgreSQL services to this file.

The Docker Compose configuration should include:

- DocuSeal application container
- PostgreSQL 18 database container
- Persistent volumes for application and database data
- PostgreSQL health check
- Restart policy
- Host port `10.0.100.51:3005` mapped to container port `3000`
- `FORCE_SSL=true`
- Database connection through the internal Docker network

Caddy is not required because Pangolin is already handling HTTPS.

## 3. Create Environment File

Generate a secure database password:

```bash
echo "DB_PASSWORD=$(openssl rand -hex 32)" | sudo tee .env > /dev/null
```

Restrict access:

```bash
sudo chmod 600 .env
```

Verify the environment file without displaying the password:

```bash
sudo ls -l .env
sudo cut -d= -f1 .env
```

## 4. Deploy DocuSeal

Validate the configuration:

```bash
sudo docker compose config --quiet
```

Pull the Docker images:

```bash
sudo docker compose pull
```

Start the containers:

```bash
sudo docker compose up -d
```

Verify container status:

```bash
sudo docker compose ps
```

Expected containers:

- `docuseal` — Running
- `docuseal-postgres` — Healthy

## 5. Configure Pangolin

Create a resource in Pangolin using the following configuration:

| Setting | Value |
|---|---|
| Resource Name | DocuSeal |
| Domain | docuseal.sws.ca |
| Target IP | 10.0.100.51 |
| Target Port | 3005 |
| Backend Protocol | HTTP |
| External Protocol | HTTPS |

Ensure Pangolin forwards the original host and HTTPS protocol headers.

Allow TCP 3005 from the Pangolin server to the Docker host through the applicable firewall controls. Restrict access from other sources. Docker-published ports can bypass ordinary UFW rules, so verify the restriction at the Docker firewall or upstream network firewall.

## 6. Initial Configuration

Open the application through Pangolin:

https://docuseal.sws.ca

Complete the initial administrator setup.

Configure the App URL:

```text
https://docuseal.sws.ca
```

This ensures signing links and email invitations use the HTTPS domain rather than the internal IP address.

## 7. Verify Connectivity

Check the application response:

```bash
curl -I http://10.0.100.51:3005
```

With `FORCE_SSL=true`, local HTTP requests may redirect to HTTPS.

The container does not terminate TLS directly, so accessing `https://10.0.100.51:3005` may produce:

```text
ERR_SSL_PROTOCOL_ERROR
```

Use the Pangolin HTTPS domain as the primary application URL.

## 8. Docker Management

Check container status:

```bash
sudo docker compose ps
```

View application logs:

```bash
sudo docker compose logs -f app
```

View PostgreSQL logs:

```bash
sudo docker compose logs -f postgres
```

Restart services:

```bash
sudo docker compose restart
```

Stop services:

```bash
sudo docker compose down
```

Start services:

```bash
sudo docker compose up -d
```

Update containers:

```bash
sudo docker compose pull
sudo docker compose up -d
```

Back up the application and database before updating. Test new image versions before adopting them.

## 9. Backup

DocuSeal application data is stored in:

```text
/data/apps/docuseal/docuseal
```

PostgreSQL data is stored in:

```text
/data/apps/docuseal/pg_data
```

Create a PostgreSQL logical backup:

```bash
cd /data/apps/docuseal
sudo mkdir -p backups

sudo docker compose exec -T postgres \
  pg_dump -U docuseal -d docuseal -Fc \
  | sudo tee backups/docuseal.dump > /dev/null
```

Also back up the DocuSeal application data directory and securely retain the database credentials. Database and document backups should represent a consistent recovery point.

Store backup copies outside the application host and periodically test restoration.

## 10. Security Recommendations

- Enforce HTTPS through Pangolin.
- Restrict TCP 3005 to the Pangolin server.
- Do not expose PostgreSQL port 5432.
- Protect administrator accounts with strong authentication.
- Use MFA where supported.
- Secure `.env` file permissions.
- Exclude secrets, databases, and document storage from Git.
- Pin tested Docker image versions instead of relying on `latest`.
- Keep DocuSeal and PostgreSQL updated.
- Maintain regular backups.
- Review signing audit trails and document retention requirements.
- Validate external signing access before enabling Pangolin authentication restrictions.

## 11. Git Repository Structure

```text
docuseal/
├── README.md
├── docker-compose.yml
└── .gitignore
```

Recommended `.gitignore`:

```gitignore
.env
docuseal/
pg_data/
backups/
*.log
*.sql
*.dump
```

## References

- [DocuSeal Official Website](https://www.docuseal.com/)
- [DocuSeal GitHub](https://github.com/docusealco/docuseal)
- [DocuSeal Docker Installation](https://www.docuseal.com/install#docker-instructions)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)
- [Pangolin](https://github.com/fosrl/pangolin)
