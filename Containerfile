ARG BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
ARG MINECRAFT_VERSION="26.3"

# Download latest Minecraft server jar
FROM registry.access.redhat.com/hi/curl:8.23.0@sha256:43402c0c7c772adbd1cf0d1ecb2bd5cfb5d706f8a46ce80d1008d41f820d65b2 AS downloader
WORKDIR /tmp
RUN ["/usr/bin/curl", "-O", "https://piston-data.mojang.com/v1/objects/33680f5f2ac32864d6d7cf5e56a705fdb3e05f4c/server.jar"]

# Run Minecraft server
FROM registry.access.redhat.com/hi/openjdk:25.0.4-runtime@sha256:6f332da2395d73a904198b44059ab6aa50e0457fe41eaad25b82fc88f13c3426
USER 65532
# Application binary
COPY --from=downloader --chown=65532:65532 /tmp/server.jar /app/server.jar
# Persistent game data (mounted at runtime)
WORKDIR /server_files
ENTRYPOINT ["/usr/bin/java", \
  "-Xmx2G", "-Xms2G", "-Xmn512M", \
  "-XX:+UseG1GC", \
  "-XX:+UnlockExperimentalVMOptions", \
  "-XX:MaxGCPauseMillis=200", \
  "-XX:G1HeapRegionSize=16M", \
  "-XX:InitiatingHeapOccupancyPercent=45", \
  "-XX:ParallelGCThreads=2", \
  "-XX:ConcGCThreads=1", \
  "-XX:MetaspaceSize=256M", \
  "-XX:MaxMetaspaceSize=512M", \
  "-XX:+AlwaysPreTouch", \
  "-XX:+UseNUMA", \
  "-XX:+DisableExplicitGC", \
  "-XX:+HeapDumpOnOutOfMemoryError", \
  "-XX:HeapDumpPath=/server_files/", \
  "-Djava.net.preferIPv4Stack=true", \
  "-jar", "/app/server.jar", "--nogui"]
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.authors="Patrick Hickey"
LABEL org.opencontainers.image.title="Hummingbird Minecraft Server"
LABEL org.opencontainers.image.description="A Minecraft server container that downloads server.jar from the Microsoft Mojang source and runs on Project Hummingbird images"
LABEL org.opencontainers.image.source="https://github.com/pshickeydev/hummingbird-minecraft"
LABEL org.opencontainers.image.documentation="https://github.com/pshickeydev/hummingbird-minecraft"
LABEL org.opencontainers.image.version="${MINECRAFT_VERSION}"
LABEL com.minecraft.license_terms="https://minecraft.net/en-us/eula"
