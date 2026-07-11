# AGENTS.md

## Project Overview

Container image that downloads the Minecraft `server.jar` from Mojang at build time and runs it on [Project Hummingbird](https://hummingbird-project.io/) distroless base images. Published to `ghcr.io/pshickeydev/hummingbird-minecraft`.

This is a **container-only project** — no application source code. The entire repository is a Containerfile, CI workflows, and automation config.

> **Note:** Any changes to this file that are relevant to users must also be reflected in `README.md`.

## Commands

```bash
# Build
podman build -t hummingbird-minecraft:latest -f Containerfile

# Lint Containerfile
hadolint Containerfile

# Run locally
podman run -d --replace --name minecraft-server \
  --memory=3.5g --cpus=1.75 \
  -v $(pwd)/server_files:/server_files:Z,U \
  -p 25565:25565 \
  hummingbird-minecraft:latest

# Verify server starts (CI does this — runs 60s then checks for EULA string)
timeout 60 podman run --rm hummingbird-minecraft:latest 2>&1 | grep 'You need to agree to the EULA'
```

## Architecture

**Two-stage Containerfile:**

1. **Downloader stage** — `registry.access.redhat.com/hi/curl` image, downloads `server.jar` from Mojang's `piston-data` CDN
2. **Runtime stage** — `registry.access.redhat.com/hi/openjdk:25-runtime` (headless JRE, ~100MB), copies jar, runs as non-root user `65532`

Persistent game data (world, configs, logs) lives in `/server_files` (the WORKDIR), mounted as a volume at runtime. The jar is at `/app/server.jar`.

**CI pipeline** (`build-push.yaml`): detect-changes → lint → build → verify (start container, grep for EULA string) → push to GHCR. Only triggers on pushes/PRs that touch `Containerfile` or the workflow itself. A `detect-changes` job diffs the Containerfile and skips the full pipeline when only the curl downloader image digest changes (e.g. Renovate curl bumps), so builds only run for Minecraft version updates or openjdk runtime image updates.

**Automated updates:**
- `update-minecraft.yaml` — checks Mojang's version manifest Tue/Wed 15:00-18:59 UTC, opens PRs with updated download URL and version ARG
- `renovate.yaml` — runs every 4h to update base image digests

## Critical Gotchas

### Distroless images have no shell

Base images are distroless — **no `/bin/sh`**. All commands must use explicit binary paths in exec form:

```dockerfile
# WRONG — fails, no shell
RUN curl -O https://example.com/server.jar
RUN java -jar /app/server.jar

# CORRECT — explicit paths, exec form
RUN ["/usr/bin/curl", "-O", "https://example.com/server.jar"]
ENTRYPOINT ["/usr/bin/java", "-jar", "/app/server.jar", "--nogui"]
```

This is the #1 source of build failures. Models are trained on standard Dockerfiles with `/bin/sh` available — that assumption breaks here.

### Minecraft version and download URL are coupled

The Containerfile has two things that must stay in sync when updating Minecraft:
- `ARG MINECRAFT_VERSION="..."` — used for the OCI image label only
- The download URL in the `curl` command — contains a version-specific hash path

The `update-minecraft.yaml` workflow updates both via `sed`. When editing manually, both must match the same Minecraft release.

### Base images are pinned by digest

Both stages use `@sha256:...` digest pins, not just tags. Renovate automates digest updates. Don't remove the digests — they ensure reproducible builds and CVE-free base images.

### Verifying base images via the Hummingbird API

The [Hummingbird catalog API](https://api-hummingbird.hummingbird-project.io) provides current image metadata. Use it to verify pinned digests are up-to-date and check CVE status:

```bash
# List current (non-superseded) tags for an image
curl -s --compressed https://api-hummingbird.hummingbird-project.io/v1/images/openjdk/tags \
  | jq '.tags[] | select(.superseded == false) | {name, digest, pull_url}'

# Check CVEs for a specific tag
curl -s --compressed "https://api-hummingbird.hummingbird-project.io/v1/images/openjdk/vulnerabilities/25.0.3-runtime" \
  | jq '{scanned_at, summary}'

# Get image details (entrypoint, env, user, etc.)
curl -s --compressed "https://api-hummingbird.hummingbird-project.io/v1/images/openjdk/details/25.0.3-runtime" \
  | jq 'to_entries[] | {arch: .key, user: .value.user, entrypoint: .value.entrypoint}'
```

Key API concepts:
- **All responses are gzip-compressed** — always pass `--compressed` to curl
- **`runtime` variant** is preferred over `default` for Java final stages (headless JRE, ~100MB vs ~120MB)
- **`builder` variant** has bash/dnf/shadow-utils for multi-stage builds; `default`/`runtime` are distroless
- **Superseded tags** — filter with `select(.superseded == false)` to get only current tags
- **Severity values** use title case: `"Critical"`, `"High"`, `"Medium"`, `"Low"`

Full API docs: https://api-hummingbird.hummingbird-project.io/v1/docs/

### Chainguard STS for CI auth

Workflows use [Chainguard OIDC short-lived tokens](https://hummingbird-project.io/) instead of long-lived secrets. Each workflow has a matching `.github/chainguard/*.sts.yaml` defining its permissions. The `octo-sts/action` mints tokens scoped to the repo.

### Volume mount flags for SELinux

The `:Z,U` mount options on `/server_files` handle SELinux relabeling and UID mapping. On non-SELinux hosts, use plain `-v $(pwd)/server_files:/server_files`.

### JVM tuning is baked into ENTRYPOINT

Heap (2GB), metaspace (512MB), G1GC flags, NUMA awareness — all hardcoded in the Containerfile `ENTRYPOINT`. Tuning for different hardware means editing the Containerfile and rebuilding.

## Conventions

- **Containerfile, not Dockerfile** — project uses `Containerfile` as the filename (Podman convention)
- **OCI labels** follow `org.opencontainers.image.*` schema; custom label `com.minecraft.license_terms` for EULA
- **GitHub Actions** pin actions by full SHA commit hash (not tags), with version comments: `@sha # v7`
- **Renovate** config extends `config:best-practices` with `group:allNonMajor`
- **PR/commit messages** from automated workflows use `chore:` prefix (conventional commits)
- **`.dockerignore`** excludes `.git`, `.github`, `*.md`, and `renovate.json` from build context
