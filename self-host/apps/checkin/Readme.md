# NLCC Sunday School Check-in

A self-hosted check-in and pickup app for Sunday school. Parents check their children in from a private link on their phone, teachers release each child with a 4-digit pickup code, and church leaders get weekly and monthly PDF attendance reports for the abuse prevention record.

Runs on any Linux PC or VM with Docker. Published to the internet through a Pangolin tunnel.

| | |
|---|---|
| Download | [`self-host/nlcc-checkin.tar.gz`](https://github.com/securewithsam/homelab/raw/refs/heads/main/self-host/nlcc-checkin.tar.gz) |
| SHA-256 | `b4e8e8c81d72fbf7e002cff464ff0313986b87b6ee571395ffbdb36d44b6f049` |
| Port | 4802 |
| Stack | FastAPI, PostgreSQL 16, Docker Compose |

---

## What it does

**For parents**
- A private link per family. No account or password. Tap **Check in everyone**, done.
- At pickup, choose who's collecting. The phone shows a 4-digit code for the teacher.
- Optional email or text reminders on Sunday morning and at pickup time. Parents turn them on or off themselves.
- Dark mode, four text sizes, and fonts chosen for low vision.

**For the foyer**
- One shared check-in station link (tablet or a printed QR code). Parents type 3+ letters of their child's name and tap Check in.
- First-time guests register their child and check in on the spot.

**For teachers**
- A live class board: who's here, care notes (allergies), who may pick up, and pickup requests.
- Release a child by entering the parent's code. Release without a code is possible but flagged in reports.
- An email for every check-in in their class, and a reminder the evening before with their lesson topic.

**For administrators**
- Classes, families, staff, and a calendar for Sundays, special events, and cancelled days.
- Branding: church name, logo, color, location, all from the admin pages.
- Weekly report emailed Sunday at 12:30, monthly report on the 1st, any date downloadable.
- Reports flag children not checked out, releases without a code, and classes below the two-adult rule.
- A full audit log of every check-in, release, sign-in and change.

---

## Requirements

- A Linux PC or VM (Ubuntu 22.04 or 24.04 recommended), 2 GB RAM, 5 GB disk
- Docker with the compose plugin
- A domain name and a [Pangolin](https://github.com/fosrl/pangolin) server (or another HTTPS reverse proxy)
- An email account that can send by SMTP (Microsoft 365, Google Workspace, or a relay like SendGrid). Optional, but reminders and reports need it.
- A Twilio account for text messages. Optional.

---

## Install

### 1. Install Docker (once per machine)

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
sudo systemctl enable --now docker
```

Log out and back in, then check with `docker compose version`.

### 2. Download and verify

```bash
sudo mkdir -p /data/apps && sudo chown $USER: /data/apps && cd /data/apps
curl -fL -o nlcc-checkin.tar.gz "https://github.com/securewithsam/homelab/raw/refs/heads/main/self-host/nlcc-checkin.tar.gz"
sha256sum nlcc-checkin.tar.gz
```

The hash must match the SHA-256 at the top of this page. If it doesn't, don't install it.

### 3. Configure

```bash
tar xzf nlcc-checkin.tar.gz && cd nlcc-checkin
cp .env.example .env
python3 -c "import secrets; print(secrets.token_hex(32))"   # copy into SECRET_KEY
python3 -c "import secrets; print(secrets.token_hex(32))"   # copy into POSTGRES_PASSWORD
nano .env
chmod 600 .env
```

Fill in at least:

| Setting | What to put |
|---|---|
| `SECRET_KEY` | First generated value. Keep it safe: changing it breaks every family link. |
| `POSTGRES_PASSWORD` | Second generated value |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | The first administrator (password 8+ characters) |
| `PUBLIC_BASE_URL` | The public address, for example `https://checkin.newlifetoronto.ca` |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM` | Your mail server. For Gmail or Microsoft 365, use an app password. |

Optional: `TWILIO_*` for texts, `REQUIRE_ADMIN_MFA=true` to force two-step sign-in for admins.

Save in nano with **Ctrl+O**, **Enter**, then exit with **Ctrl+X**.

### 4. Start

```bash
docker compose up -d --build
docker compose ps                  # app should be "healthy"
curl -s localhost:4802/healthz     # {"ok":true}
```

The first build takes a few minutes.

### 5. Publish through Pangolin

1. In Pangolin, create a **Site** for the church and run the Newt command it gives you on this machine.
2. Create a resource for your domain (for example `checkin.newlifetoronto.ca`) pointing at `localhost:4802` on that site. If Newt runs in Docker, use `<this-pc-lan-ip>:4802`.
3. Confirm the certificate is valid (no browser warning). If you see a self-signed certificate, Let's Encrypt hasn't issued one yet: check that port 80 reaches the Pangolin server.
4. If Pangolin sign-in is on for the resource, add rules that **always allow** these paths, one rule per path:

| Path | Why |
|---|---|
| `/f/*` | Family check-in links |
| `/checkin/*` | Check-in station link |
| `/static/*` | Styles and scripts |
| `/branding/*` | Logo |
| `/healthz` | Health check |

Staff pages (`/login`, `/admin`, `/teacher`) can stay behind Pangolin sign-in for an extra layer. Teachers then need Pangolin accounts too.

> Sign-in only works over HTTPS. To test at `http://<pc-ip>:4802` on the local network, set `COOKIE_SECURE=false` temporarily, then set it back to `true`.

### 6. Make the machine reliable

The scheduler sends Sunday reminders and reports, so the machine must stay on.

```bash
# never sleep
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
# automatic security updates
sudo apt install -y unattended-upgrades
```

Also set the BIOS to power on after a power failure. Docker and the app start by themselves on boot.

---

## Getting started

### First sign-in

1. Open `https://<your-domain>/login` and sign in with `ADMIN_EMAIL` and `ADMIN_PASSWORD`.
2. Go to your name in the menu (Profile):
   - Change the password, then remove `ADMIN_PASSWORD` from `.env`.
   - Turn on two-step sign-in. Optional, but recommended: this account can see every child's details.

### Set up the church

Work through the menu from left to right.

**Settings**
- Church name, program name, office phone, location, brand color, logo.
- **Public web address**: your HTTPS address. Every emailed link uses it.
- Sunday check-in times, reminder times, and **report recipients** (keep this list short).
- Press **Send test email** to confirm email works.
- **Check-in station link**: print the QR code for the foyer, or open the link on a tablet there.

**Classes**
- Add each class (for example Kindergarten, Ages 6 to 10, Ages 11 to 14) with its room.
- Open a class to add children. Choose an existing family, or fill in **New family** with a parent's name, email and mobile.

**Families**
- On each family page, check the guardians and children, and add anyone else allowed to pick up (grandparents, sitters), one name per line.
- Add care notes for teachers: allergies, medication, what helps a child settle.
- Press **Email link to guardians**. The QR code on the page can be printed for families who prefer paper.

**Staff**
- Add every teacher. Give **Can sign in** and a password only to people who use the class board on Sunday.
- Teachers without a sign-in still get reminder emails.

**Calendar**
- Sundays have class automatically. Open any day to:
  - Add teachers, choose their class, and write the **lesson or topic**.
  - Press **Save and email** to send that teacher their reminder now, or **Email all teachers** with an optional message.
  - Add an event (VBS, Christmas program) with its own start and end time.
  - **Cancel class this day** for holidays. No reminders go out.

### A normal Sunday

| Time | What happens |
|---|---|
| Evening before, 6:00 PM | Rostered teachers get their class and lesson by email |
| 9:00 AM | Check-in opens on family links and the station |
| 10:55 AM | Reminder to families who haven't checked in |
| Each check-in | The class's teachers get an email |
| 12:00 PM | Pickup reminder, only to families with a child still checked in |
| 12:30 PM | Weekly PDF report emailed to report recipients |
| 1st of the month, 8:00 AM | Monthly PDF report |

All times and on/off switches are in **Settings**. Events on the calendar use their own times.

**Parents:** open the family link, tap **Check in**. At pickup, tap **Pick up**, choose who's collecting, and show the code to the teacher.

**Teachers:** sign in and open **Class board**. Pickup requests appear at the top in amber. Type the parent's code and tap **Release**. For a child without a phone, use **Check in a child without a phone** and type part of the name.

**Administrators:** **Today** shows live counts, who's on duty, and new guest families to review.

### Who can do what

| | Parent link | Station link | Teacher | Admin |
|---|:---:|:---:|:---:|:---:|
| Check a child in | Own children | Any child (by name search) | Any child | Any child |
| Request pickup | Yes | No | | |
| Release a child | | | Yes | Yes |
| See care notes | | | Yes | Yes |
| Families, classes, settings, reports | | | | Yes |

---

## Day-to-day operations

```bash
cd /data/apps/nlcc-checkin
docker compose ps                         # status
docker compose logs -f app scheduler      # live logs
docker compose restart                    # restart
```

### Backups

Attendance history is part of your child-safety record. Back it up nightly and keep copies off this machine.

```bash
crontab -e
```

Add:

```
0 2 * * * cd /data/apps/nlcc-checkin && docker compose exec -T db pg_dump -U checkin checkin | gzip > ~/nlcc-backup-$(date +\%F).sql.gz
```

Back up `.env` too. Without the same `SECRET_KEY`, old family links stop working.

Restore:

```bash
gunzip -c ~/nlcc-backup-YYYY-MM-DD.sql.gz | docker compose exec -T db psql -U checkin checkin
```

### Update to a new version

Your `.env` and database are kept. New database columns are added automatically.

```bash
cd /data/apps
curl -fL -o nlcc-checkin.tar.gz "https://github.com/securewithsam/homelab/raw/refs/heads/main/self-host/nlcc-checkin.tar.gz"
sha256sum nlcc-checkin.tar.gz             # compare with the hash at the top
tar xzf nlcc-checkin.tar.gz
cd nlcc-checkin && docker compose up -d --build
docker compose logs --tail=20 app
```

### Remove completely

This deletes every family, child and attendance record. Back up first.

```bash
cd /data/apps/nlcc-checkin
docker compose down --volumes --rmi all --remove-orphans
cd /data/apps && rm -rf nlcc-checkin
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Family link shows a Pangolin login | Add the always-allow path rules (step 5) |
| Browser warns about the certificate | Let's Encrypt hasn't issued one. Check port 80 on the Pangolin server, then restart Traefik. |
| Can't stay signed in | You're on `http://`. Use the HTTPS address, or set `COOKIE_SECURE=false` for local testing only. |
| "This page doesn't exist" on a family link | The link was replaced or `SECRET_KEY` changed. Copy a fresh link from the family page. |
| No emails | Check `SMTP_*` in `.env`, run `docker compose up -d`, and press **Send test email** in Settings. Many cloud providers block port 25; use 587. |
| Links in emails point to the wrong address | Change **Public web address** in Settings. Editing `.env` doesn't change it after the first start. |
| Locked out | Another admin can unlock the account or reset two-step sign-in under **Staff**. |

---

## Security

- Passwords hashed with bcrypt; accounts lock for 15 minutes after 5 failed attempts.
- Optional two-step sign-in (authenticator app) with one-time backup codes.
- Signed, HttpOnly, Secure cookies; CSRF protection on every form; strict Content Security Policy with no inline scripts.
- Rate limiting on sign-in, family links and the check-in station.
- Containers run as a non-root user with a read-only filesystem and no Linux capabilities. The database isn't reachable from outside Docker.
- Secrets (database, email, Twilio) live only in `.env`, never in the database or the admin pages.
- The station link shows only first names and last initials, needs 3+ letters to search, and can never release a child.
- Deleting a child or family keeps past attendance (name only) in the reports.

**Never commit your real `.env` to this repository.** It contains the keys to every family link.
