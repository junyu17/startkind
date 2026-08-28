# StartKind backend — deployment to startk.livepet.ren

## What this backend is (and is not)

After the CloudKit migration the server holds **no personal data**. Task text,
history, recovery capsules and calibration live in the user's own iCloud and
sync device-to-device without touching this box. The server does exactly three
things:

1. **AI proxy** — holds the DeepSeek API key, which must never ship inside the app,
   and enforces the Free daily allowance server-side.
2. **Co-start rooms** — short-lived shared state for two people working in
   parallel. Reaped after 2 hours; deleted after 7 days.
3. **Entitlement verification** — verifies the Apple-signed StoreKit 2
   transaction *locally* against Apple's root certificates. No Apple credential
   lives on this box, and no round trip to Apple is made (measured: a call to
   Apple's App Store Server API from this VPS costs ~160-195ms; local
   verification is ~1-5ms).

Identity is an **anonymous device token**. No accounts, no email, no password.
Only the SHA-256 hash of the token is stored, so the database never holds a
credential that could be replayed if it leaked.

## Target box

`192.255.128.176` (`racknerd-4a5d666`), Ubuntu 22.04, **1963 MB RAM / 2 cores**.

That is why this is a single ~100 MB container reusing the Postgres that is
already running, rather than a self-hosted Supabase stack (which needs ~4 GB).

## What is already there and must keep working

| Running | Note |
|---|---|
| `sslh` on public :443 | demuxes TLS to nginx, SSH to `127.0.0.1:22` |
| `deploy-nginx-1` | serves livepet.ren, www, ppace.livepet.ren, trainer.livepet.ren |
| `deploy-postgres-1` | Postgres 16 — **reused**, with a separate database and role |
| `deploy-backend-1`, `platepace-*` | untouched |
| `xray` on 172.18.0.1:10081/10082 | untouched |

This deployment mirrors the PlatePace gateway pattern already proven here:
joins the existing external network `deploy_default`, **publishes no ports**,
and adds exactly one `server_name`.

## Change list (what actually gets modified)

1. **New database + role** in the existing Postgres. Nothing existing is altered.
2. **New container** `startkind-api` on the existing `deploy_default` network,
   no published ports, `mem_limit: 320m`.
3. **One new file** `/root/livepet/deploy/nginx/conf.d/startk.conf`.
   No existing conf.d file is edited.
3b. **One new static-site directory** `/root/livepet/deploy/site/startkind/`
   (index, privacy, stylesheet, screenshots). The existing `site/` contents
   for livepet / ppace / trainer are untouched.
4. **One new certificate** for `startk.livepet.ren` via the existing certbot
   webroot. Existing certificates are not renewed or replaced.
5. `nginx -t` then `nginx -s reload` — a reload, not a restart, so live
   connections to the other four sites are not dropped.

Nothing else on the box is touched. Rollback is: remove `startk.conf`, reload
nginx, `docker compose down`, drop the database.

## Steps

```bash
# 0. From the Mac, sync the server directory up.
rsync -avz -e "ssh -p 443 -o ProxyCommand=none -i ~/.ssh/livepet_vps" \
  server/ root@192.255.128.176:/root/livepet/startkind/

# 1. Database + role (run on the VPS).
docker exec -i deploy-postgres-1 psql -U postgres <<'SQL'
CREATE ROLE startkind LOGIN PASSWORD 'REPLACE_ME';
CREATE DATABASE startkind OWNER startkind;
SQL
docker exec -i deploy-postgres-1 psql -U startkind -d startkind \
  < /root/livepet/startkind/sql/001_init.sql

# 2. Secrets. Never commit this file.
cat > /root/livepet/startkind/.env <<'ENV'
STARTKIND_DATABASE_URL=postgres://startkind:REPLACE_ME@deploy-postgres-1:5432/startkind
STARTKIND_AI_API_KEY=...            # DeepSeek key (OpenAI-compatible endpoint)
ENV
chmod 600 /root/livepet/startkind/.env

# 3. Build and start.
cd /root/livepet/startkind && docker compose up -d --build
docker exec startkind-api deno eval "console.log(await (await fetch('http://localhost:8080/health')).text())"

# 4. Certificate. Bootstrap vhost first (HTTP only), then the real vhost.
#    The acme-challenge location in startk.conf serves the same webroot certbot uses.
docker compose -f /root/livepet/deploy/docker-compose.yml run --rm certbot \
  certonly --webroot -w /var/www/certbot -d startk.livepet.ren

# 5. Publish the static site (index + privacy + screenshots).
rsync -avz -e "ssh -p 443 -o ProxyCommand=none -i ~/.ssh/livepet_vps" \
  site/ root@192.255.128.176:/root/livepet/deploy/site/startkind/

# 6. Install the vhost and reload (NOT restart).
cp /root/livepet/startkind/nginx/startk.conf /root/livepet/deploy/nginx/conf.d/
docker exec deploy-nginx-1 nginx -t && docker exec deploy-nginx-1 nginx -s reload

# 7. Verify from outside.
curl -sS https://startk.livepet.ren/health
curl -sS -X POST https://startk.livepet.ren/v1/device/register
curl -sSI https://startk.livepet.ren/ | head -1
curl -sSI https://startk.livepet.ren/privacy.html | head -1
```

## Reaping

`reap_stale_costart_rooms()` ends rooms older than 2 hours and deletes rooms
ended more than 7 days ago. Schedule it daily:

```
0 4 * * * docker exec deploy-postgres-1 psql -U startkind -d startkind -c "select reap_stale_costart_rooms();"
```

## API

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/health` | none | liveness |
| POST | `/v1/device/register` | none | issue an anonymous device token |
| POST | `/v1/next-step` | Bearer | AI next step (Free: 5/day) |
| POST | `/v1/admin-parse` | Bearer | admin parse (Plus only) |
| POST | `/v1/transaction` | Bearer | verify signed transaction, set entitlement |
| POST | `/v1/costart/rooms` | Bearer | create a room |
| POST | `/v1/costart/rooms/join` | Bearer | join by six-digit code |
| GET | `/v1/costart/rooms/:id/participants` | Bearer | participants (members only) |
| POST | `/v1/costart/rooms/:id/end` | Bearer | end a room (host only) |
| POST | `/v1/costart/rooms/:id/outcome` | Bearer | record own outcome |
