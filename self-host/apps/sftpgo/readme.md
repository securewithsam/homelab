# 1. Copy all three files to your server
# 2. Edit .env with a real password


```bash
unzip sftpgo.zip -d sftpgo
cd sftpgo
mkdir -p data config backups

# Set ownership to match the container's UID/GID (1000:1000)
sudo chown -R 1000:1000 data config backups

chmod +x setup.sh
./setup.sh
docker compose up -d
```


# 3. Hit http://<your-ip>:8099/web/admin

