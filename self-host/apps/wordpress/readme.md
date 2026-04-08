Great to hear that it’s working! 🎉

Below is a **ready-to-use `README.md` file** that you can add to your GitHub repository. It includes setup instructions for the `docker-compose.yml`, `.env` configuration, permissions, and steps to bring the environment up.

---

# 📄 README.md – WordPress Docker Setup for Rapid7 Testing

```markdown
# WordPress Docker Lab for Rapid7 InsightIDR Testing

This repository provides a simple Docker-based WordPress environment designed for security testing and SIEM (Rapid7 InsightIDR) integration. It enables visibility into WordPress application-layer events such as admin logins, plugin changes, and user privilege modifications.

## 📌 Overview

- **WordPress**: Customer-facing web application
- **MySQL**: Backend database
- **Docker Compose**: Container orchestration
- **Rapid7 InsightIDR**: SIEM integration for security monitoring
- **Use Case**: Proof-of-concept for application-layer logging and detection

## 📂 Repository Structure

```

.
├── docker-compose.yml
├── .env.example
└── README.md

````

> ⚠️ **Note:** The actual `.env` file should not be committed to the repository as it contains sensitive credentials.

---

## 🛠️ Prerequisites

Ensure the following are installed on your Ubuntu system:

- Docker Engine
- Docker Compose (v2+)
- Git (optional)

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
sudo usermod -aG sudo security-admin
sudo usermod -aG docker security-admin
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

---

## 📊 Rapid7 InsightIDR Integration

### 1. Install a WordPress Activity Logging Plugin

Recommended plugins:

* **WP Activity Log**
* **Stream**
* **Wordfence** (optional)

These plugins generate security-relevant events such as:

* Successful and failed logins
* Plugin and theme changes
* User role modifications
* File changes

### 2. Enable WordPress Debug Logging

If not already enabled, ensure the following settings are present in `wp-config.php`:

```php
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);
```

Logs will be generated at:

```
/var/www/html/wp-content/debug.log
```

On the Docker host, the log path is typically:

```
/var/lib/docker/volumes/wordpress/_data/wp-content/debug.log
```

### 3. Install the Rapid7 Insight Agent

Install the agent using the command provided in the Rapid7 Insight Platform:

```bash
curl -L https://repos.insight.rapid7.com/insight-agent/download.sh | sudo bash
```

Verify the agent status:

```bash
sudo systemctl status ir_agent
```

### 4. Configure Log Collection

Configure Rapid7 to monitor the WordPress log file:

```
/var/lib/docker/volumes/wordpress/_data/wp-content/debug.log
```

Generate test events (e.g., failed logins, plugin installations) and confirm their visibility in InsightIDR.

---

## 🔐 File Permissions Summary

| File/Directory       | Recommended Permission | Purpose                       |
| -------------------- | ---------------------- | ----------------------------- |
| `docker-compose.yml` | `644`                  | Readable by Docker            |
| `.env`               | `600`                  | Protect sensitive credentials |
| Project Directory    | `755`                  | Standard directory access     |

Commands:

```bash
chmod 644 docker-compose.yml
chmod 600 .env
chmod 755 .
```

---

## 🧪 Useful Commands

| Action                 | Command                  |
| ---------------------- | ------------------------ |
| Start containers       | `docker compose up -d`   |
| Stop containers        | `docker compose down`    |
| Remove volumes         | `docker compose down -v` |
| View logs              | `docker compose logs -f` |
| List containers        | `docker ps`              |
| Validate configuration | `docker compose config`  |

---

## 🛡️ Security Considerations

* Do not commit the `.env` file to version control.
* Use strong passwords for database credentials.
* Restrict WordPress admin access where applicable.
* Regularly update Docker images and WordPress plugins.
* Treat Docker group membership as privileged access.

---

## 📌 Troubleshooting

### Port Already in Use

```bash
sudo lsof -i :8085
```

Update the port in the `.env` file if necessary.

### Containers Not Starting

```bash
docker compose logs
```

### Permission Issues

```bash
sudo chown -R $USER:$USER .
```

---

## 🧹 Cleanup

To stop and remove the environment:

```bash
docker compose down -v
```

---

## 📄 License

This project is intended for internal security testing and proof-of-concept purposes.

---

## 👤 Author

**Security Team**
For questions or support, please contact the IT Security team.

````

---

## ✅ Additional Files to Include in GitHub

### `.env.example`
```env
WP_DB_NAME=ectestwp-db
WP_DB_USER=ectestwp-user
WP_DB_PASSWORD=ChangeThisPassword
WORDPRESS_PORT=8085
````

### `.gitignore`

```gitignore
# Ignore sensitive environment variables
.env

# Ignore logs and temporary files
*.log
```

---

## 🎯 Summary

You can now:

* ✅ Add this `README.md` to your GitHub repository.
* ✅ Include `docker-compose.yml` and `.env.example`.
* ❌ Exclude the real `.env` file using `.gitignore`.
* ✅ Provide clear setup instructions for others to replicate your Rapid7 WordPress lab.

If you’d like, I can also help you create:

* A **Rapid7 detection rule set**
* An **architecture diagram**
* A **one-page PoC summary** for leadership

Just let me know—happy to assist! 🚀
