# Hummingbird Minecraft Server

A Minecraft server container that downloads `server.jar` from Mojang at build time and runs on [Project Hummingbird](https://hummingbird-project.io/) minimal, hardened, distroless images via Podman.

The image is published to `ghcr.io/pshickeydev/hummingbird-minecraft`.

## Build

```bash
podman build -t hummingbird-minecraft:latest -f Containerfile
```

## Run

```bash
podman run -d --replace --name minecraft-server \
  --memory=3.5g --cpus=1.75 \
  -v $(pwd)/server_files:/server_files:Z,U \
  -p 25565:25565 \
  ghcr.io/pshickeydev/hummingbird-minecraft:latest
```

The `:Z,U` mount options handle SELinux relabeling and ensure the volume persists after container update.

These run instructions and all resource settings are based on a VPS host with 2 vCPU and 4GB RAM. Adjust the `--memory` and `--cpus` flags for your hardware.

This runs the server with all persistent data (world, configs, etc.) stored on the host `server_files/` directory. The container is limited to 3.5GB of RAM and 1.75 of the 2 available CPUs.

## JVM tuning

The JVM is configured with:

- 2GB heap (`-Xms2g -Xmx2g`)
- 512MB metaspace (`-XX:MetaspaceSize=512m`)
- G1GC tuned for game server workloads (`-XX:G1HeapRegionSize=4`, `-XX:InitiatingHeapOccupancyPercent=25`, `-XX:G1ReservePercent=10`, etc.)
- NUMA awareness (`-XX:+UseNUMA`)
- IPv4 stack (`-Djava.net.preferIPv4Stack=true`)

## Upgrading

```bash
podman stop minecraft-server && \
podman rm -f minecraft-server && \
podman rmi -f ghcr.io/pshickeydev/hummingbird-minecraft:latest && \
podman run -d --replace --name minecraft-server \
  --memory=3.5g --cpus=1.75 \
  -v $(pwd)/server_files:/server_files:Z,U \
  -p 25565:25565 \
  ghcr.io/pshickeydev/hummingbird-minecraft:latest
```

Your world and configuration are preserved since they live on the host in `./server_files/`.

## Automated updates

Three GitHub Actions workflows keep the project maintained:

- **build-push** — Lints the Containerfile, builds the image, verifies it starts correctly, and pushes to GHCR on every `main` push that changes the Containerfile or the workflow itself, with SLSA build provenance attestations.
- **renovate** — Runs every 4 hours to update base image dependencies.
- **update-minecraft** — Runs on Tue/Wed afternoons UTC to check Mojang's manifest for new Minecraft releases and opens PRs automatically.
