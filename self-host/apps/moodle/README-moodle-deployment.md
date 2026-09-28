# Moodle 5.2 HomeLab Deployment Runbook

This runbook documents the working Moodle deployment built and tested on the HomeLab Ubuntu server, including the fixes encountered during installation.

## 1. Target architecture

- Ubuntu Docker host: `10.0.100.51`
- Application directory: `/data/apps/moodle`
- Moodle: `5.2.3`
- PHP: `8.3` + Apache
- PostgreSQL: `16`
- Moodle origin port: `9999`
- Public URL: `https://lms.sws.ca`
- Public access: Pangolin reverse proxy/tunnel
- Database is Docker-internal only; PostgreSQL port 5432 is not published to the host.
- Moodle code is baked into the image.
- `moodledata`, PostgreSQL data, PHP configuration, and Moodle `config.php` persist outside the application container.

Traffic flow:

```text
Internet/User
    |
    | HTTPS 443
    v
https://lms.sws.ca
    |
    v
Pangolin
    |
    | HTTP
    v
10.0.100.51:9999
    |
    v
Moodle container
    |
    +---- PostgreSQL (private Docker network)
```

## 2. Prerequisites

Verify Docker and Docker Compose:

```bash
docker --version
docker compose version
```

The tested lab had Docker 29.3.0 and Docker Compose v5.1.0.

Create the application directories:

```bash
sudo mkdir -p /data/apps/moodle
cd /data/apps/moodle

sudo mkdir -p moodledata postgres
sudo chown -R "$USER":"$USER" /data/apps/moodle
```

## 3. Create `.env`

```bash
nano .env
```

Example:

```dotenv
POSTGRES_DB=moodle
POSTGRES_USER=moodle
POSTGRES_PASSWORD=CHANGE_ME_TO_A_STRONG_PASSWORD

MOODLE_ADMIN_USER=moodleadmin
MOODLE_ADMIN_PASSWORD=CHANGE_ME
MOODLE_ADMIN_EMAIL=admin@example.com

MOODLE_PORT=9999
```

Protect it:

```bash
chmod 600 .env
```

Do not commit `.env` or production secrets to Git.

## 4. Create the Moodle Docker image

Create `/data/apps/moodle/Dockerfile`:

```dockerfile
FROM php:8.3-apache

ARG MOODLE_VERSION=5.2.3

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip \
    libfreetype6-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libpq-dev \
    libxml2-dev \
    libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        exif \
        gd \
        intl \
        opcache \
        pgsql \
        pdo_pgsql \
        soap \
        zip \
    && rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite headers remoteip

RUN curl -fsSL \
    "https://download.moodle.org/download.php/direct/stable502/moodle-${MOODLE_VERSION}.tgz" \
    -o /tmp/moodle.tgz \
    && tar -xzf /tmp/moodle.tgz -C /var/www/ \
    && rm /tmp/moodle.tgz \
    && chown -R root:root /var/www/moodle \
    && find /var/www/moodle -type d -exec chmod 755 {} \; \
    && find /var/www/moodle -type f -exec chmod 644 {} \;

ENV APACHE_DOCUMENT_ROOT=/var/www/moodle/public

RUN sed -ri \
    -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
    /etc/apache2/sites-available/*.conf \
    /etc/apache2/apache2.conf \
    /etc/apache2/conf-available/*.conf

WORKDIR /var/www/moodle
```

Build it:

```bash
cd /data/apps/moodle

docker build \
  --build-arg MOODLE_VERSION=5.2.3 \
  -t homelab-moodle:5.2.3 .
```

Verify:

```bash
docker images | grep homelab-moodle
```

## 5. Create PHP configuration

Create `/data/apps/moodle/moodle.ini`:

```ini
; Moodle production PHP configuration

zend.exception_ignore_args = On

max_input_vars = 5000

memory_limit = 512M

upload_max_filesize = 1024M
post_max_size = 1024M

max_execution_time = 300
max_input_time = 300

opcache.enable = 1
opcache.memory_consumption = 256
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 60

expose_php = Off
display_errors = Off
log_errors = On
```

The 1 GB upload limit was selected to allow larger SCORM/course packages.

## 6. Create Docker Compose

Create `/data/apps/moodle/compose.yml`:

```yaml
services:

  postgres:
    image: postgres:16
    container_name: moodle-postgres
    restart: unless-stopped

    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}

    volumes:
      - ./postgres:/var/lib/postgresql/data

    networks:
      - moodle-backend

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 20s

  moodle:
    image: homelab-moodle:5.2.3
    container_name: moodle-app
    restart: unless-stopped

    depends_on:
      postgres:
        condition: service_healthy

    ports:
      - "${MOODLE_PORT}:80"

    volumes:
      - ./moodledata:/var/www/moodledata
      - ./moodle.ini:/usr/local/etc/php/conf.d/99-moodle.ini:ro
      - ./config.php:/var/www/moodle/config.php:ro

    networks:
      - moodle-backend

networks:
  moodle-backend:
    driver: bridge
```

### Important: local Moodle image

`homelab-moodle:5.2.3` is locally built, so do **not** use a generic:

```bash
docker compose pull
```

That causes Docker to try to pull `homelab-moodle:5.2.3` from a public registry.

Pull PostgreSQL specifically:

```bash
docker compose pull postgres
```

Then start:

```bash
docker compose up -d
```

Verify:

```bash
docker compose ps
```

Expected:

- `moodle-postgres` healthy
- `moodle-app` running
- Host port `9999` mapped to container port `80`

Test the origin:

```bash
curl -I http://127.0.0.1:9999
```

During initial installation, a redirect to `install.php` is expected.

## 7. Fix `moodledata` permissions

If the Moodle installer reports that the data directory cannot be created or written:

```bash
cd /data/apps/moodle

sudo chown -R 33:33 moodledata
sudo chmod -R 770 moodledata
```

Validate from the container:

```bash
docker exec moodle-app bash -c \
'id www-data && ls -ld /var/www/moodledata && touch /var/www/moodledata/testfile && rm /var/www/moodledata/testfile'
```

## 8. Moodle database installer settings

Use:

```text
Database driver: PostgreSQL
Database host:   postgres
Database name:   moodle
Database user:   moodle
Database port:   5432
Tables prefix:   mdl_
Unix socket:     blank
```

Use the actual `POSTGRES_PASSWORD` from `.env`.

**Do not use `localhost` as the database host.** `postgres` is the Docker Compose service name and resolves across the private Docker network.

## 9. Moodle `config.php`

The Moodle installer may be unable to write `config.php` because the application code is intentionally not writable by Apache.

Create it manually on the host:

```bash
cd /data/apps/moodle
sudo nano config.php
```

Working structure:

```php
<?php

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = 'pgsql';
$CFG->dblibrary = 'native';
$CFG->dbhost    = 'postgres';
$CFG->dbname    = 'moodle';
$CFG->dbuser    = 'moodle';
$CFG->dbpass    = 'CHANGE_ME_TO_ACTUAL_DB_PASSWORD';
$CFG->prefix    = 'mdl_';

$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => 5432,
  'dbsocket' => '',
);

$CFG->wwwroot  = 'https://lms.sws.ca';
$CFG->sslproxy = true;

$CFG->dataroot = '/var/www/moodledata';
$CFG->admin    = 'admin';

$CFG->directorypermissions = 0770;

require_once(__DIR__ . '/lib/setup.php');
```

Protect it while allowing Apache/PHP (`www-data`, GID 33) to read it:

```bash
sudo chown root:33 config.php
sudo chmod 640 config.php
```

Verify numerically:

```bash
ls -ln config.php
```

Expected ownership/mode similar to:

```text
-rw-r----- 1 0 33 ... config.php
```

Validate that `www-data` can read it:

```bash
docker exec -u www-data moodle-app \
  php -r 'echo is_readable("/var/www/moodle/config.php") ? "READABLE\n" : "NOT READABLE\n";'
```

Expected:

```text
READABLE
```

## 10. Important fix: HTTP 500 after container recreation

### Symptom

Moodle returned HTTP 500 after:

```bash
docker compose up -d --force-recreate moodle
```

Logs showed errors similar to:

```text
require_once(/var/www/moodle/config.php): Failed to open stream: Permission denied
Fatal error: Failed opening required '/var/www/moodle/public/../config.php'
```

Inside the container, `config.php` appeared as:

```text
-rw------- 1 1000 1000 ...
```

### Cause

`config.php` is a host bind mount:

```yaml
- ./config.php:/var/www/moodle/config.php:ro
```

Therefore, the **host file's ownership and permissions control access**. A previous `chown` performed only inside the container does not solve the problem after the container is recreated.

### Permanent fix

Run on the host:

```bash
cd /data/apps/moodle

sudo chown root:33 config.php
sudo chmod 640 config.php
```

Then:

```bash
docker exec -u www-data moodle-app \
  php -r 'echo is_readable("/var/www/moodle/config.php") ? "READABLE\n" : "NOT READABLE\n";'
```

No image rebuild or database reinstall is required for this issue.

## 11. Verify PHP settings

After mounting `moodle.ini`, recreate the Moodle container if needed:

```bash
docker compose up -d --force-recreate moodle
```

Check:

```bash
docker exec moodle-app php -i | grep -E \
"zend.exception_ignore_args|max_input_vars|upload_max_filesize|post_max_size|memory_limit"
```

Expected values:

```text
max_input_vars => 5000 => 5000
memory_limit => 512M => 512M
post_max_size => 1024M => 1024M
upload_max_filesize => 1024M => 1024M
zend.exception_ignore_args => On => On
```

## 12. Pangolin public resource

Create the Pangolin public resource with the Moodle server as the origin:

```text
Protocol: HTTP
Target:   10.0.100.51
Port:     9999
```

Public hostname:

```text
https://lms.sws.ca
```

Pangolin terminates HTTPS externally and proxies HTTP to the Moodle origin.

### Moodle canonical URL fix

Initially Moodle used:

```php
$CFG->wwwroot = 'http://10.0.100.51:9999';
```

This caused users visiting the public subdomain to be redirected back to:

```text
http://10.0.100.51:9999/login/index.php
```

The fix was:

```php
$CFG->wwwroot  = 'https://lms.sws.ca';
$CFG->sslproxy = true;
```

After this change, Moodle correctly remains on the public HTTPS hostname.

Normal user access should therefore use:

```text
https://lms.sws.ca
```

Do not use the private IP/port as the normal Moodle browser URL after setting the canonical public URL.

## 13. Troubleshooting commands

Container status:

```bash
cd /data/apps/moodle
docker compose ps
```

Moodle logs:

```bash
docker compose logs --tail=100 moodle
```

PostgreSQL logs:

```bash
docker compose logs --tail=100 postgres
```

Follow Moodle logs:

```bash
docker compose logs -f moodle
```

Test local origin:

```bash
curl -I http://127.0.0.1:9999
```

Test LAN origin:

```bash
curl -I http://10.0.100.51:9999
```

Test public endpoint:

```bash
curl -I https://lms.sws.ca
```

Inspect redirect chain:

```bash
curl -IL https://lms.sws.ca
```

Check Moodle config permissions:

```bash
ls -ln /data/apps/moodle/config.php

docker exec moodle-app ls -ln /var/www/moodle/config.php
```

Check DB health:

```bash
docker exec moodle-postgres \
  pg_isready -U moodle -d moodle
```

## 14. Useful lifecycle commands

Start:

```bash
cd /data/apps/moodle
docker compose up -d
```

Stop containers without deleting persistent data:

```bash
docker compose stop
```

Restart Moodle:

```bash
docker compose restart moodle
```

Recreate Moodle after a Compose configuration change:

```bash
docker compose up -d --force-recreate moodle
```

Rebuild the Moodle image after a Dockerfile change:

```bash
docker build \
  --build-arg MOODLE_VERSION=5.2.3 \
  -t homelab-moodle:5.2.3 .

docker compose up -d --force-recreate moodle
```

## 15. Current security design

The deployment intentionally follows these principles:

- Only Moodle's origin HTTP port is published.
- PostgreSQL is not exposed to the LAN/Internet.
- Application and database communicate on a private Docker network.
- Moodle application source is baked into the container image.
- `config.php` is mounted read-only into the application container.
- `config.php` is root-owned and readable by the web-server group only.
- `moodledata` is outside the public Moodle web root.
- Public TLS terminates at Pangolin.
- Moodle uses its HTTPS public FQDN as `$CFG->wwwroot`.
- `$CFG->sslproxy = true` tells Moodle that HTTPS is being handled by the reverse proxy.
- PHP error display is disabled while logging remains enabled.

## 16. Items still to complete before treating this as the final enterprise build

This README captures the **working state reached so far**. The following were not yet completed/tested and should not be assumed to be production-ready:

1. Resolve Moodle 5.2 Composer/vendor check in the Docker image.
2. Configure and validate the Moodle 5.2 router with Apache.
3. Complete the Moodle installation and validate health checks.
4. Add Moodle cron running every minute.
5. Add Redis for Moodle cache/session use.
6. Upload and validate representative SCORM packages.
7. Configure Microsoft Entra ID SSO/OIDC.
8. Retain and protect a local break-glass Moodle administrator.
9. Configure trusted reverse-proxy settings as required.
10. Implement database and `moodledata` backups and perform a restore test.
11. Add container/log rotation, monitoring, health checks, and alerting.
12. Pin production container/image versions and establish an upgrade process.
13. Review firewall rules so port 9999 is reachable only where required (ideally only from the Pangolin path).
14. Validate production sizing/concurrency for the expected user population.
15. Perform security hardening and application testing before enterprise deployment.

## 17. Deployment checklist for the next server

```text
[ ] Install/verify Docker + Compose
[ ] Create /data/apps/moodle
[ ] Create moodledata and postgres directories
[ ] Create protected .env with NEW environment-specific secrets
[ ] Create Dockerfile
[ ] Build homelab-moodle:5.2.3 (or approved newer version)
[ ] Create moodle.ini
[ ] Create compose.yml
[ ] Pull PostgreSQL image
[ ] Start PostgreSQL + Moodle
[ ] Fix moodledata ownership (UID/GID 33 where applicable)
[ ] Configure Moodle PostgreSQL connection using host "postgres"
[ ] Create config.php
[ ] Set config.php root:33 / 640
[ ] Confirm config.php is readable by www-data
[ ] Set environment's canonical HTTPS FQDN in $CFG->wwwroot
[ ] Set $CFG->sslproxy = true when TLS terminates at Pangolin
[ ] Configure Pangolin HTTP origin -> server:9999
[ ] Validate local origin
[ ] Validate public HTTPS URL
[ ] Validate redirect chain
[ ] Review Moodle server checks
[ ] Complete remaining production-hardening items
```

---

## Key lesson from this build

For this Docker design, treat `/data/apps/moodle/config.php` as the authoritative configuration file. Because it is bind-mounted read-only into the Moodle container, its **host ownership and permissions persist across container recreation**.

For reverse-proxy deployment, Moodle's `$CFG->wwwroot` must be the **public canonical HTTPS URL**, not the private Docker/LAN origin address.
