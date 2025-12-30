# =========================================================================
# Stage 1: The Builder
# =========================================================================
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates wget dpkg-dev gcc g++ libc6-dev libssl-dev make pax-utils

ENV REDIS_VERSION=7.2.5
ENV REDIS_DOWNLOAD_URL=http://download.redis.io/releases/redis-7.2.5.tar.gz

RUN set -eux; \
    wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL"; \
    mkdir -p /usr/src/redis; \
    tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1; \
    rm redis.tar.gz; \
    make -C /usr/src/redis -j "$(nproc)" all; \
    make -C /usr/src/redis install

COPY redis-init.c /tmp/redis-init.c
RUN gcc -static -O2 -o /redis-init /tmp/redis-init.c

RUN mkdir /gathered-libs
RUN lddtree -l /usr/local/bin/redis-server | grep '^/' | sort -u | xargs -r cp --parents -t /gathered-libs/

RUN apt-get purge -y --auto-remove \
    ca-certificates wget dpkg-dev gcc g++ libc6-dev libssl-dev make pax-utils \
    && rm -rf /var/lib/apt/lists/*

FROM gcr.io/distroless/static-debian12

COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

COPY --from=builder /redis-init /redis-init
COPY --from=builder /usr/local/bin/redis-server /usr/local/bin/redis-server

COPY --from=builder /gathered-libs/ /

COPY --chown=999:999 redis.conf /data/redis.conf
VOLUME /data
WORKDIR /data
EXPOSE 6379

ENTRYPOINT ["/redis-init"]
CMD ["/data/redis.conf"]