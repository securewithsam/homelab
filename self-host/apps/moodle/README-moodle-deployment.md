# Moodle 5.2 Production Deployment Guide

Production deployment runbook for Moodle 5.2 using Docker Compose, PostgreSQL, PHP/Apache, and Pangolin as the external HTTPS reverse proxy.

> **Deployment model:** Application code is built into an immutable container image. PostgreSQL and Moodle data are persistent. PostgreSQL remains private. Moodle is published externally only through the reverse-proxy path.

---

## 1. Architecture

```text
User / Browser
      |
      | HTTPS 443
      v
https://lms.sws.ca
      |
      v
Pangolin
      |
      | HTTP :9999
      v
Moodle Server
      |
      +--> Moodle 5.2.3 / PHP 8.3 / Apache
      |
      +--> PostgreSQL 16
           Private Docker network
```

### Deployment parameters

| Component | Value |
|---|---|
| Application directory | `/data/apps/moodle` |
| Moodle | `5.2.3` |
| PHP | `8.3` |
| PostgreSQL | `16` |
| Moodle origin port | `9999` |
| Public URL | `https://lms.sws.ca` |
| Application image | `sws-moodle:5.2.3` |

---

## 2. Prerequisites

Verify Docker Engine and Docker Compose:

```bash
docker --version
docker compose version
```

Create the application directories:

```bash
sudo mkdir -p /data/apps/moodle
cd /data/apps/moodle

sudo mkdir -p moodledata postgres
sudo chown -R "$USER":"$USER" /data/apps/moodle
```

---

## 3. Environment File

Create the environment file:

```bash
cd /data/apps/moodle
nano .env
```

Add:

```dotenv
POSTGRES_DB=moodle
POSTGRES_USER=moodle
POSTGRES_PASSWORD=<STRONG_UNIQUE_DATABASE_PASSWORD>

MOODLE_ADMIN_USER=moodleadmin
MOODLE_ADMIN_PASSWORD=<STRONG_UNIQUE_ADMIN_PASSWORD>
MOODLE_ADMIN_EMAIL=<ADMIN_EMAIL>

MOODLE_PORT=9999
```

Protect the file:

```bash
chmod 600 .env
```

> Do not commit `.env` or production credentials to Git.

---

## 4. Moodle Docker Image

Create `Dockerfile`:

```bash
nano Dockerfile
```

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

Build the image:

```bash
docker build \
  --build-arg MOODLE_VERSION=5.2.3 \
  -t sws-moodle:5.2.3 .
```

Verify:

```bash
docker images | grep sws-moodle
```

---

## 5. PHP Configuration

Create:

```bash
nano moodle.ini
```

Add:

```ini
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

The 1 GB request/upload limit accommodates larger SCORM and course packages.

---

## 6. Moodle Configuration

Create:

```bash
nano config.php
```

Add:

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
$CFG->dbpass    = '<DATABASE_PASSWORD>';
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

Set the required ownership and permissions:

```bash
sudo chown root:33 config.php
sudo chmod 640 config.php
```

Verify:

```bash
ls -ln config.php
```

Expected ownership:

```text
UID: 0
GID: 33
Mode: 640
```

---

## 7. Moodle Data Directory

Set ownership and permissions:

```bash
sudo chown -R 33:33 /data/apps/moodle/moodledata
sudo chmod -R 770 /data/apps/moodle/moodledata
```

`moodledata` must remain outside Moodle's public web root.

---

## 8. Docker Compose

Create:

```bash
nano compose.yml
```

Add:

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
    image: sws-moodle:5.2.3
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

Pull PostgreSQL:

```bash
docker compose pull postgres
```

The Moodle application image is built locally, so a generic `docker compose pull` is not required.

---

## 9. Start Moodle

Start the platform:

```bash
cd /data/apps/moodle

docker compose up -d
```

Check status:

```bash
docker compose ps
```

Expected:

```text
moodle-postgres   Up (healthy)
moodle-app        Up
```

The application should be published locally on:

```text
http://<MOODLE_SERVER_IP>:9999
```

Verify the origin:

```bash
curl -I http://127.0.0.1:9999
```

---

## 10. Validate Persistent Permissions

Confirm that Moodle can read `config.php`:

```bash
docker exec -u www-data moodle-app \
  php -r 'echo is_readable("/var/www/moodle/config.php") ? "READABLE\n" : "NOT READABLE\n";'
```

Expected:

```text
READABLE
```

Confirm that Moodle can write to `moodledata`:

```bash
docker exec moodle-app bash -c \
'id www-data && ls -ld /var/www/moodledata && touch /var/www/moodledata/testfile && rm /var/www/moodledata/testfile'
```

---

## 11. Database Configuration

When configuring Moodle, use:

| Setting | Value |
|---|---|
| Database driver | PostgreSQL |
| Database host | `postgres` |
| Database name | `moodle` |
| Database user | `moodle` |
| Database password | Value of `POSTGRES_PASSWORD` |
| Database port | `5432` |
| Tables prefix | `mdl_` |
| Unix socket | Blank |

The database hostname is `postgres` because Moodle and PostgreSQL communicate through the private Docker network.

Do not use `localhost`.

---

## 12. Pangolin Reverse Proxy

Create the public resource in Pangolin:

```text
Public hostname: https://lms.sws.ca

Origin protocol: HTTP
Origin target:   <MOODLE_SERVER_IP>
Origin port:     9999
```

The resulting flow is:

```text
https://lms.sws.ca
        |
        | HTTPS
        v
     Pangolin
        |
        | HTTP :9999
        v
   Moodle Server
```

Moodle must use the external HTTPS hostname as its canonical URL:

```php
$CFG->wwwroot  = 'https://lms.sws.ca';
$CFG->sslproxy = true;
```

Use the public FQDN for normal user and administrator access:

```text
https://lms.sws.ca
```

---

## 13. Validate PHP Configuration

Run:

```bash
docker exec moodle-app php -i | grep -E \
"zend.exception_ignore_args|max_input_vars|upload_max_filesize|post_max_size|memory_limit"
```

Expected:

```text
max_input_vars => 5000 => 5000
memory_limit => 512M => 512M
post_max_size => 1024M => 1024M
upload_max_filesize => 1024M => 1024M
zend.exception_ignore_args => On => On
```

---

## 14. Deployment Validation

### Containers

```bash
docker compose ps
```

### PostgreSQL

```bash
docker exec moodle-postgres \
  pg_isready -U moodle -d moodle
```

### Local origin

```bash
curl -I http://127.0.0.1:9999
```

### Public endpoint

```bash
curl -I https://lms.sws.ca
```

### Redirect chain

```bash
curl -IL https://lms.sws.ca
```

All browser-facing redirects should remain on the public FQDN.

---

## 15. Operational Commands

### Start

```bash
cd /data/apps/moodle
docker compose up -d
```

### Status

```bash
docker compose ps
```

### Moodle logs

```bash
docker compose logs --tail=100 moodle
```

### PostgreSQL logs

```bash
docker compose logs --tail=100 postgres
```

### Follow Moodle logs

```bash
docker compose logs -f moodle
```

### Restart Moodle

```bash
docker compose restart moodle
```

### Recreate Moodle after configuration changes

```bash
docker compose up -d --force-recreate moodle
```

### Rebuild after Dockerfile changes

```bash
docker build \
  --build-arg MOODLE_VERSION=5.2.3 \
  -t sws-moodle:5.2.3 .

docker compose up -d --force-recreate moodle
```

---

## 16. Production Security Baseline

- PostgreSQL is available only on the private Docker network.
- PostgreSQL port `5432` is not published to the host.
- Only the Moodle origin port required by Pangolin is exposed.
- Restrict TCP `9999` to the Pangolin path at the host/network layer where possible.
- `moodledata` resides outside the public Moodle web root.
- `config.php` is mounted read-only into the Moodle container.
- `config.php` is root-owned and readable only by the required web-server group.
- `.env` is excluded from source control and protected with restrictive permissions.
- Production deployments use unique secrets.
- TLS terminates at Pangolin.
- Moodle uses the external HTTPS FQDN as its canonical URL.
- PHP error display is disabled.
- Application and reverse-proxy logs should be centrally retained and monitored.
- Backups must include PostgreSQL, `moodledata`, Moodle configuration, and deployment configuration.
- Restore procedures must be tested before production go-live.
- Maintain a protected local break-glass administrator when enterprise SSO is enabled.

---

## 17. Production Readiness

Before enterprise go-live, validate:

- [ ] Moodle installation completes without blocking environment checks.
- [ ] Moodle 5.2 Apache/router configuration is validated for the final release.
- [ ] Required Composer/vendor dependencies are included in the final application image.
- [ ] Moodle cron runs every minute.
- [ ] Redis is configured for production cache/session use if included in the final architecture.
- [ ] Representative SCORM packages upload and execute successfully.
- [ ] SCORM completion tracking and reporting are validated.
- [ ] Microsoft Entra ID SSO/OIDC is configured.
- [ ] MFA and Conditional Access requirements are applied.
- [ ] Local break-glass administrative access is tested.
- [ ] PostgreSQL backup and restore are tested.
- [ ] `moodledata` backup and restore are tested.
- [ ] Container and application log rotation is configured.
- [ ] Health monitoring and alerting are configured.
- [ ] Vulnerability scanning and security validation are completed.
- [ ] Capacity and concurrency testing match the expected production population.
- [ ] Patch and upgrade procedures are documented and tested.

---

## 18. Final Verification

```text
[ ] PostgreSQL container healthy
[ ] Moodle container healthy/running
[ ] PostgreSQL not externally exposed
[ ] config.php ownership = root:33
[ ] config.php permissions = 640
[ ] config.php readable by www-data
[ ] moodledata writable by Moodle
[ ] moodledata not web accessible
[ ] Public HTTPS FQDN loads successfully
[ ] Redirects remain on public FQDN
[ ] PHP limits validated
[ ] Pangolin origin configured correctly
[ ] Administrative access tested
[ ] SSO tested
[ ] SCORM tested
[ ] Cron validated
[ ] Backups validated
[ ] Restore tested
[ ] Monitoring and alerting validated
```

---

## Deployment Principle

> **Build once, keep application code immutable, persist only required data and configuration, expose only the reverse-proxied application path, and use the public HTTPS FQDN as Moodle's canonical identity.**
