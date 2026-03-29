Here's your master config with everything consolidated. Quick recap of what's in there:

**Networking:** Web UI on `8099`, SFTP on `2022`, FTP and WebDAV disabled (port `0`)

**Defender:** Enabled with `provider` driver, 30-min bans escalating on repeat offenses, custom scoring that penalizes scanners and invalid usernames harder

**Rate Limiting:** 100 req/s per IP with burst of 50, tied into defender for auto-banning

**Connection Limits:** 50 total, 10 per IP

**SFTP Hardening:** 3 max auth tries, generic banner, modern KEX algorithms only

**Web UI Hardening:** Token bound to source IP, login URL hidden

**Password Hardening:** Bcrypt cost 12, minimum entropy 50 for both admins and users

**Infrastructure:** Non-root container (UID 1000), 512MB memory cap, health checks, log rotation, 60s graceful shutdown

**Post-deploy checklist** (do these in the web admin after first login):
1. Change admin password
2. Enable MFA/TOTP on your admin account
3. Create users with SSH key auth where possible
4. Set per-user quotas and permissions (don't use `*`)
5. Add your LAN (`10.0.100.0/24`) to the defender allow list
