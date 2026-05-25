ARG MINECRAFT_SERVER_JAR_URL

# Download Minecraft server jar
FROM quay.io/hummingbird/curl:8.20.0@sha256:98b3f40a11815db552fc525884c08f4fcb2c63d372eb402b66632e3ee5640e51 AS downloader
WORKDIR /tmp
RUN ["/usr/bin/curl", "-o", "server.jar", "${MINECRAFT_SERVER_JAR_URL}"]

# Run Minecraft server
FROM quay.io/hummingbird/openjdk:25.0.3-runtime@sha256:1aa412d8d94fa07eccd14a928d4ffd603e52ec948b376e1280c7bef6ab02e7d2
USER 65532
COPY --from=downloader --chown=65532:65532 /tmp/server.jar /app/server.jar
WORKDIR /server_files
ENTRYPOINT ["/usr/bin/java", "-Xmx3G", "-Xms512M", "-XX:SoftMaxHeapSize=2G", "-jar", "/app/server.jar", "--nogui"]
