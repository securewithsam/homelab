# CrowdSec Console Enrollment Guide

> Connect your self-hosted CrowdSec instance to the CrowdSec Console for visual dashboards, real-time attack maps, and access to the community blocklist.

---

## Why Enroll?

By default CrowdSec is working and blocking threats but you have no visibility into what it's doing. Enrolling in the CrowdSec Console unlocks:

| Feature | Description |
|---------|-------------|
| 🗺️ Live Attack Map | See attacks on your server in real time by country |
| 📊 Dashboard | Blocked IPs, attack types, top threats |
| 🚫 Community Blocklist | Millions of known bad IPs automatically blocked before they hit your server |
| 📈 Metrics | Decisions made, alerts triggered over time |
| 🔔 Alerts | Get notified when your server is under attack |

---

## Prerequisites

- A free account at [app.crowdsec.net](https://app.crowdsec.net)
- CrowdSec running in Docker (as set up in the main guide)

---

## Enrollment Steps

### Step 1 — Get your enrollment key

1. Log into [app.crowdsec.net](https://app.crowdsec.net)
2. Go to **Security Engines** → **Add Security Engine**
3. Copy the enrollment key displayed on screen

### Step 2 — Enroll your instance

```bash
docker exec crowdsec cscli console enroll <YOUR_ENROLLMENT_KEY>
```

### Step 3 — Restart CrowdSec

```bash
docker compose restart crowdsec
```

### Step 4 — Approve in the console

1. Go back to [app.crowdsec.net](https://app.crowdsec.net)
2. Navigate to **Security Engines**
3. You will see your instance (named `pangolin-crowdsec`) listed as pending
4. Click **Accept** to approve it

Your instance will appear as **Online** within a few seconds.

---

## Verify Enrollment

Check that your instance is enrolled and the console is enabled:

```bash
docker exec crowdsec cscli console status
```

Expected output:

```
Console status:
├── Enrolled: ✔
├── Console credentials file: /etc/crowdsec/console.yaml
└── Console URL: https://app.crowdsec.net
```

---

## After Enrolling

### Enable the community blocklist

Once enrolled, CrowdSec will automatically subscribe your instance to the community blocklist — millions of known malicious IPs are blocked before they even attempt to connect to your server.

Verify the blocklist is being pulled:

```bash
docker exec crowdsec cscli hub list
```

### Check decisions being made

```bash
docker exec crowdsec cscli decisions list
```

### Check active alerts

```bash
docker exec crowdsec cscli alerts list
```

---

## Notes

> ⚠️ **Never test bans with your own IP.** If you want to smoke test, use a secondary IP such as a mobile hotspot.

```bash
# Add a 1-minute test ban on a test IP
docker exec crowdsec cscli decisions add --ip <TEST_IP> -d 1m --type ban

# Remove it after testing
docker exec crowdsec cscli decisions delete --ip <TEST_IP>
```

---

## References

- [CrowdSec Console](https://app.crowdsec.net)
- [CrowdSec Enrollment Docs](https://docs.crowdsec.net/docs/next/console/enrollment)
- [CrowdSec Hub — Collections & Scenarios](https://hub.crowdsec.net)
