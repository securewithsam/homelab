# SFTPGo Homelab — Security Hardening Documentation

> **Version:** 1.0  
> **Image:** `drakkan/sftpgo:v2.7.0`  
> **Author:** Sam — Senior Security Manager  
> **Last Updated:** March 2026

---

## Overview

This document details the security controls applied to the self-hosted SFTPGo deployment running on the homelab infrastructure. The configuration prioritizes defense-in-depth with layered controls across network, application, authentication, and infrastructure domains.

---

## Network Controls

### Exposed Services

| Service | Port | Status |
|---------|------|--------|
| Web UI / REST API | `8099` | Enabled |
| SFTP | `2022` | Enabled |
| FTP/S | `0` | **Disabled** |
| WebDAV | `0` | **Disabled** |

FTP and WebDAV are explicitly disabled at the application level by setting their binding port to `0`. This eliminates unnecessary protocol attack surface. Only SFTP (encrypted by default) and the HTTPS-capable Web UI are exposed.

### Firewall Rules (UFW)

The `setup.sh` script configures host-level firewall rules:

- `8099/tcp` — SFTPGo Web UI (ALLOW)
- `2022/tcp` — SFTPGo SFTP (ALLOW)
- All other SFTPGo-related ports are implicitly denied

### Connection Limits

| Setting | Value | Purpose |
|---------|-------|---------|
| `MAX_TOTAL_CONNECTIONS` | 50 | Caps total concurrent connections server-wide |
| `MAX_PER_HOST_CONNECTIONS` | 10 | Caps concurrent connections from a single IP |

Exceeding `MAX_PER_HOST_CONNECTIONS` generates `SCORE_LIMIT_EXCEEDED` events that feed into the brute-force defender, enabling automatic banning of aggressive hosts.

---

## Brute-Force Defender

The built-in defender acts as an application-level fail2ban alternative, protecting SFTP, HTTP, FTP, and WebDAV services.

### Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| `DRIVER` | `provider` | Stores defender data in SQLite database (persists across restarts) |
| `BAN_TIME` | 30 min | Duration of initial ban |
| `BAN_TIME_INCREMENT` | 50 | Multiplier for repeat offenders (escalating bans) |
| `THRESHOLD` | 5 | Cumulative score before ban triggers |
| `OBSERVATION_TIME` | 15 min | Rolling window for tracking failed attempts |

### Scoring Model

| Event | Score | Rationale |
|-------|-------|-----------|
| Valid username, wrong password | 1 | Legitimate typos get more grace |
| Non-existent username | 2 | Credential stuffing hits threshold faster (3 attempts) |
| Connect without auth (scanners) | 2 | Penalizes port scanners and bots |
| Rate limit / connection limit exceeded | 3 | Aggressive hosts banned quickly |

**Escalation behavior:** A scanner connecting without auth scores 2 per attempt, hitting the ban threshold of 5 in just 3 connections. After the initial 30-minute ban, repeat offenders receive progressively longer bans via the `BAN_TIME_INCREMENT` multiplier.

---

## Rate Limiting

| Setting | Value | Description |
|---------|-------|-------------|
| `AVERAGE` | 100 req/s | Sustained request rate per IP |
| `BURST` | 50 | Maximum burst above average |
| `TYPE` | 1 (per IP) | Rate limiting applied per source IP |
| `PROTOCOLS` | SSH, HTTP, FTP, DAV | All protocols covered |
| `GENERATE_DEFENDER_EVENTS` | true | Violations feed into defender scoring |
| `ENTRIES_SOFT_LIMIT` | 100 | Soft cap on in-memory rate limiter entries |
| `ENTRIES_HARD_LIMIT` | 150 | Hard cap on in-memory rate limiter entries |

The rate limiter is integrated with the defender — any IP exceeding the rate limit accumulates `SCORE_LIMIT_EXCEEDED` points (score: 3), meaning two rate limit violations trigger an automatic ban.

---

## SFTP Protocol Hardening

### Authentication Controls

| Setting | Value | Description |
|---------|-------|-------------|
| `MAX_AUTH_TRIES` | 3 | Max authentication attempts per connection before forced disconnect |
| `PASSWORD_AUTHENTICATION` | true (default) | Can be set to `false` to enforce SSH key-only auth |

### Banner Sanitization

The default SFTPGo banner reveals software name and version information. This has been replaced with a generic `Welcome` string to prevent version fingerprinting.

### Key Exchange Algorithms

Only modern, secure KEX algorithms are permitted:

- `curve25519-sha256`
- `curve25519-sha256@libssh.org`
- `ecdh-sha2-nistp256`
- `ecdh-sha2-nistp384`
- `ecdh-sha2-nistp521`

Legacy and weak algorithms (diffie-hellman-group1, diffie-hellman-group14, etc.) are excluded by explicitly defining this allow list.

---

## Web UI Hardening

| Setting | Value | Description |
|---------|-------|-------------|
| `SECURITY__ENABLED` | true | Binds session tokens to source IP — prevents session hijacking if a token is stolen |
| `HIDE_LOGIN_URL` | 3 | Hides login URL from unauthenticated users to reduce discovery surface |

---

## Password Hardening

### Hashing

| Setting | Value | Description |
|---------|-------|-------------|
| `BCRYPT_OPTIONS__COST` | 12 | Increased from default of 10 — each increment doubles computation time for brute force |

### Complexity Requirements

| Setting | Value | Description |
|---------|-------|-------------|
| Admin minimum entropy | 50 | Enforced at admin account creation/password change |
| User minimum entropy | 50 | Enforced at user account creation/password change |

Password entropy is calculated using the zxcvbn algorithm, which evaluates password strength based on pattern matching, common passwords, and dictionary attacks rather than simple character-class rules.

---

## Container Infrastructure Security

### Non-Root Execution

The container runs as `UID:GID 1000:1000` — never as root. Host directories (`data`, `config`, `backups`) are owned by `1000:1000` with permissions set to `750`.

### Resource Constraints

| Setting | Value | Purpose |
|---------|-------|---------|
| Memory limit | 512 MB | Prevents runaway memory consumption from impacting host |
| Memory reservation | 128 MB | Guarantees minimum allocation |

### Image Pinning

The image is pinned to `drakkan/sftpgo:v2.7.0` rather than `:latest` to prevent unreviewed code changes from being pulled on container restart. Image updates should be deliberate and tested.

### Health Monitoring

| Setting | Value |
|---------|-------|
| Health check command | `sftpgo ping` |
| Interval | 30 seconds |
| Timeout | 10 seconds |
| Retries | 3 |
| Start period | 10 seconds |

Docker will automatically mark the container as unhealthy and restart it if the health check fails 3 consecutive times.

### Graceful Shutdown

`stop_grace_period` is set to 60 seconds, allowing active file transfers to complete before the container is terminated.

### Log Management

| Setting | Value |
|---------|-------|
| Log driver | json-file |
| Max file size | 10 MB |
| Max file count | 3 |

Total log retention is capped at 30 MB to prevent disk exhaustion.

---

## Post-Deployment Checklist

These steps must be completed manually in the SFTPGo Web Admin (`http://<host>:8099/web/admin`) after first launch:

- [ ] Change the default admin password immediately
- [ ] Enable MFA/TOTP on the admin account (Settings > Two-Factor Auth)
- [ ] Add the trusted LAN (`10.0.100.0/24`) to the defender allow list
- [ ] Create SFTP users with SSH key authentication (preferred over passwords)
- [ ] Set per-user permissions — avoid using `*` (wildcard all permissions)
- [ ] Set per-user storage quotas appropriate to available disk
- [ ] Review and test defender behavior with a failed login simulation

---

## Future Hardening Considerations

- **SSH Key-Only Auth:** Disable password authentication globally via `SFTPGO_SFTPD__PASSWORD_AUTHENTICATION=false` once all users have SSH keys configured.
- **TLS on Web UI:** Configure ACME/Let's Encrypt or place behind Pangolin reverse proxy with TLS termination (e.g., `sftp.securewithsam.com`).
- **CORS Restriction:** Set `SFTPGO_HTTPD__CORS__ALLOWED_ORIGINS` to your specific domain when behind reverse proxy.
- **Prometheus Monitoring:** Enable telemetry endpoint for metrics collection and alerting on security events.
- **Automated Backups:** Schedule database and configuration backups from the `/srv/sftpgo/backups` volume.
- **CrowdSec Integration:** Pair with existing CrowdSec deployment on `sws-pangolin-01` for shared threat intelligence and IP reputation scoring.

---

## File Structure

```
sftpgo/
├── docker-compose.yml    # Master configuration (all security controls)
├── .env                  # Admin credentials (change before first run)
├── setup.sh              # First-time directory and firewall setup
├── SECURITY.md           # This document
├── data/                 # User home dirs, virtual folders, uploads
├── config/               # SQLite database, host keys
└── backups/              # SFTPGo backup exports
```

---

## References

- [SFTPGo Documentation](https://docs.sftpgo.com/latest/)
- [SFTPGo Defender Configuration](https://docs.sftpgo.com/2.6/defender/)
- [SFTPGo Configuration File Reference](https://docs.sftpgo.com/2.6/config-file/)
- [SFTPGo Environment Variables](https://docs.sftpgo.com/2.6/env-vars/)
- [SFTPGo GitHub Repository](https://github.com/drakkan/sftpgo)
