FROM debian:bookworm-slim AS builder-src

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    ca-certificates wget dpkg-dev gcc g++ libc6-dev libssl-dev make; \
    rm -rf /var/lib/apt/lists/*

ENV REDIS_VERSION=7.2.4
ENV REDIS_DOWNLOAD_URL=http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz

RUN set -eux; \
    wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL"; \
    mkdir -p /usr/src/redis; \
    tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1; \
    rm redis.tar.gz; \
    make -C /usr/src/redis -j "$(nproc)" all; \
    make -C /usr/src/redis install

COPY redis-init.c /usr/src/redis-init.c
RUN gcc -static -O2 -o /usr/local/bin/redis-init /usr/src/redis-init.c && \
    chmod +x /usr/local/bin/redis-init

FROM redis:7-bookworm AS builder-official

USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends libc-bin gawk binutils && \
    mkdir /distroless-deps && \
    ldd -r /usr/local/bin/redis-server 2>/dev/null | awk 'NF==4{print $3}' | grep -v '^$' | sort -u | \
    xargs -r cp --parents -t /distroless-deps/ || true && \
    rm -rf /var/lib/apt/lists/*

USER redis

FROM gcr.io/distroless/cc-debian12:nonroot

COPY --from=builder-official /etc/passwd /etc/passwd
COPY --from=builder-official /etc/group /etc/group

COPY --from=builder-official /distroless-deps /

COPY --from=builder-src /usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=builder-src /usr/local/bin/redis-init /usr/local/bin/redis-init

COPY --chown=redis:redis redis.conf /data/redis.conf

VOLUME /data
WORKDIR /data
EXPOSE 6379

USER root
ENTRYPOINT ["/usr/local/bin/redis-init"]
CMD ["/data/redis.conf"]
