# All-in-one lab: vulnerable Arcane + git daemon + exploit.sh, canary only.
#   docker build -f poc/Dockerfile -t arcane-symlink-poc .
#   docker run --rm arcane-symlink-poc
#   docker build -f poc/Dockerfile -t arcane-symlink-poc:patched --build-arg ARCANE_VERSION=v2.8.0 .

ARG ARCANE_VERSION=v2.7.0

FROM ghcr.io/getarcaneapp/arcane:${ARCANE_VERSION} AS arcane

FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl ca-certificates python3 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=arcane /app/arcane /opt/arcane/arcane
COPY poc/entrypoint.sh exploit.sh /opt/poc/
RUN chmod +x /opt/poc/*.sh /opt/arcane/arcane \
 && mkdir -p /opt/arcane/data /lab && chmod -R 777 /opt/arcane/data /lab

WORKDIR /opt/arcane
ENV PORT=3552 \
    ENVIRONMENT=production \
    GIN_MODE=release \
    ENCRYPTION_KEY=0123456789abcdef0123456789abcdef \
    JWT_SECRET=poc-lab-secret-change-me-0123456789

ENTRYPOINT ["/opt/poc/entrypoint.sh"]
