# Hummingbird Minecraft Server

A Minecraft server container that downloads server.jar from the Microsoft Mojang source and runs on Fedora Project Hummingbird-based images via Podman.

## Build

```bash
podman build -t hummingbird-minecraft:latest -f Containerfile
```

Local builds require `MINECRAFT_SERVER_JAR_URL` as a build argument. Override the version by setting it to the desired Mojang server JAR URL:

```bash
podman build \
  --build-arg MINECRAFT_SERVER_JAR_URL="https://piston-data.mojang.com/v1/objects/<hash>/server.jar" \
  -t hummingbird-minecraft:latest -f Containerfile
```

## Run

```bash
podman run -d --replace --name minecraft-server \
  -v $(pwd)/server_files:/server_files:Z,U \
  -p 25565:25565 \
  ghcr.io/pshickeydev/hummingbird-minecraft:latest
```

This runs the server with all persistent data (world, configs, etc.) stored in the local `server_files/` directory.

## Upgrading

```bash
podman stop minecraft-server && \
podman rm -f minecraft-server && \
podman rmi -f ghcr.io/pshickeydev/hummingbird-minecraft:latest && \
podman run -d --replace --name minecraft-server \
  -v $(pwd)/server_files:/server_files:Z,U \
  -p 25565:25565 \
  ghcr.io/pshickeydev/hummingbird-minecraft:latest
```

Your world and configuration are preserved since they live on the host in `./server_files/`.
