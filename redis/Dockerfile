# =================================================================
# Stage 1: The "Builder Source"
# Builds Redis from source & compiles the custom C helper
# =================================================================
FROM debian:bookworm-slim AS builder-src


# 1. Install Build Dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    ca-certificates wget dpkg-dev gcc g++ libc6-dev libssl-dev make; \
    rm -rf /var/lib/apt/lists/*


# 2. Build Redis
ENV REDIS_VERSION=7.2.4
ENV REDIS_DOWNLOAD_URL=http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz

RUN set -eux; \
    wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL"; \
    mkdir -p /usr/src/redis; \
    tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1; \
    rm redis.tar.gz; \
    make -C /usr/src/redis -j "$(nproc)" all; \
    make -C /usr/src/redis install

# 3. Compile the Custom Init Helper (From local file)
COPY redis-init.c /usr/src/redis-init.c
RUN gcc -static -O2 -o /usr/local/bin/redis-init /usr/src/redis-init.c && \
    chmod +x /usr/local/bin/redis-init

# =================================================================
# Stage 2: The "Builder Official"
# Uses the official Debian 12 (bookworm) Redis image as a source.
# =================================================================
FROM redis:7-bookworm AS builder-official

USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends libc-bin gawk && \
    mkdir /distroless-deps && \
    ldd /usr/local/bin/redis-server | awk 'NF == 4 {print $3}' | xargs -I {} cp -v {} /distroless-deps && \
    rm -rf /var/lib/apt/lists/*

USER redis

# =================================================================
# Stage 3: The Final "Distroless" Image
# Using Debian 12 base to match the builder stage for library compatibility.
# =================================================================
FROM gcr.io/distroless/cc-debian12:nonroot

# Copy user and group files for the 'redis' user
# (Taking from official builder ensures correct IDs)
COPY --from=builder-official /etc/passwd /etc/passwd
COPY --from=builder-official /etc/group /etc/group

# Copy all discovered shared libraries from the builder
COPY --from=builder-official /distroless-deps/ /lib/x86_64-linux-gnu/

# COPY --from=builder-official /lib/x86_64-linux-gnu/ /lib/x86_64-linux-gnu/
# COPY --from=builder-official /usr/lib/x86_64-linux-gnu/ /usr/lib/x86_64-linux-gnu/

# Copy the Redis server binary
# (Taking from source builder because it's the version we compiled)
COPY --from=builder-src /usr/local/bin/redis-server /usr/local/bin/redis-server

# Copy the Custom Init Helper
COPY --from=builder-src /usr/local/bin/redis-init /usr/local/bin/redis-init

# Optional: Copy redis-cli for debugging and health checks (currently commented out)
# COPY --from=builder-official /usr/local/bin/redis-cli /usr/local/bin/redis-cli

# Copy custom configuration from the build context
COPY --chown=redis:redis redis.conf /data/redis.conf

# Define a volume for data persistence
VOLUME /data

# Set the working directory
WORKDIR /data

# Expose the default Redis port
EXPOSE 6379

# The HEALTHCHECK is disabled as it requires redis-cli.
# HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
#   CMD ["/usr/local/bin/redis-cli", "ping"]

# Switch to root initially (Required for redis-init to fix sysctl)
USER root

# Set the entrypoint to our custom fixer, which then execs redis-server
ENTRYPOINT ["/usr/local/bin/redis-init"]
CMD ["/data/redis.conf"]
