ARG BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
ARG MINECRAFT_VERSION="26.2"

# Download latest Minecraft server jar
FROM registry.access.redhat.com/hi/curl:8.21.0@sha256:b26d8b9930b218186c662cecaab99da943da5ef7d6cdb510beb371736237c744 AS downloader
WORKDIR /tmp
RUN ["/usr/bin/curl", "-O", "https://piston-data.mojang.com/v1/objects/823e2250d24b3ddac457a60c92a6a941943fcd6a/server.jar"]

# Run Minecraft server
FROM registry.access.redhat.com/hi/openjdk:25.0.3-runtime@sha256:8230bf6b730bf6b71327c3c9bbc8b962ad2ac7fbb46b3359241e29dd6647e906
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
