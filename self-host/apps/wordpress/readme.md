### Install Docker (if not already installed)

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
````

### Grant User Permissions

Add your user to the `sudo` and `docker` groups:

```bash
sudo usermod -aG sudo infra-admin
sudo usermod -aG docker infra-admin
```

Apply the changes by logging out and back in, or by running:

```bash
newgrp docker
```

---

## ⚙️ Environment Configuration

### 1. Create the `.env` File

Copy the example environment file and update the values:

```bash
cp .env.example .env
nano .env
```

Example `.env` content:

```env
WP_DB_NAME=ectestwp-db
WP_DB_USER=ectestwp-user
WP_DB_PASSWORD=Str0ngP@ssw0rd!
WORDPRESS_PORT=8085
```

### 2. Secure the `.env` File

Restrict permissions to protect sensitive credentials:

```bash
chmod 600 .env
```

---

## 🚀 Deployment Steps

### 1. Validate the Docker Compose Configuration

```bash
docker compose config
```

This ensures that the YAML syntax and environment variables are correct.

### 2. Start the Environment

```bash
docker compose up -d
```

### 3. Verify Running Containers

```bash
docker ps
```

You should see containers similar to:

* `wordpress`
* `db`

### 4. Access WordPress

Open a browser and navigate to:

```
http://localhost:8085
```

Complete the WordPress installation by creating an administrator account.

