#!/usr/bin/env bash
# Regenerate lab/netbox/initdb/netbox.sql.gz: a dump of a freshly migrated,
# otherwise empty NetBox database (813 migrations, plus the admin user and
# its API token from netbox.env). Postgres loads it the first time it starts
# on an empty volume, so NetBox skips its migrations: in a Codespace they
# take ~6 minutes. Rerun this after changing the NetBox image in
# lab/netbox/compose.yml; a stale dump still works, as NetBox then applies
# only the newer migrations.
#
# Deletes NetBox's current data: it boots NetBox from an empty volume.
set -euo pipefail

cd "$(dirname "$0")/.."
compose=(docker compose -f lab/netbox/compose.yml)
# The dump must contain the admin user and token, which NetBox creates only
# when this is false (compose.yml defaults it to true).
export NETBOX_SKIP_SUPERUSER=false
out="lab/netbox/initdb/netbox.sql.gz"

# Boot from a truly empty database: set the old dump aside, so Postgres
# starts blank and NetBox runs every migration itself. Put it back if
# anything fails.
aside="$(mktemp)"
fresh="$(mktemp)"
if [ -f "$out" ]; then mv "$out" "$aside"; fi
trap 'if [ ! -f "$out" ] && [ -s "$aside" ]; then mv "$aside" "$out"; fi; rm -f "$aside" "$fresh"' EXIT

"${compose[@]}" down -v
"${compose[@]}" up -d --wait --wait-timeout 900 netbox

# Sessions are per-login; nothing else in a fresh NetBox is worth dropping.
"${compose[@]}" exec -T postgres \
    pg_dump -U netbox -d netbox --no-owner --no-privileges --exclude-table-data=django_session \
    | gzip -9 -n >"$fresh"
# mktemp makes it 0600; Postgres reads it as its own user in the container.
chmod 644 "$fresh"
mv "$fresh" "$out"

"${compose[@]}" down -v
echo "Wrote ${out} ($(wc -c <"$out" | tr -d ' ') bytes). Run 'just lab-up' or 'just netbox-up' to start NetBox again."
