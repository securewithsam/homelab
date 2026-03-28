#!/bin/bash
###############################################################################
# SFTPGo - First-time setup script
# Run this ONCE before 'docker compose up -d'
###############################################################################

set -e

echo "==> Creating SFTPGo directories..."
mkdir -p data config backups

echo "==> Setting ownership to UID/GID 1000 (matches container default)..."
sudo chown -R 1000:1000 data config backups

echo "==> Setting permissions..."
chmod 750 data config backups

echo ""
echo "============================================"
echo "  SFTPGo directories ready!"
echo ""
echo "  BEFORE YOU START:"
echo "  1. Edit .env and set a strong admin password"
echo "  2. Run: docker compose up -d"
echo "  3. Open: http://<your-ip>:8099/web/admin"
echo "  4. Change admin password immediately"
echo "  5. Create your first SFTP user"
echo "============================================"
