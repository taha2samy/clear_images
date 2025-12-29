# ==========================================
# Stage 1: Builder
# ==========================================
FROM cgr.dev/chainguard/wolfi-base AS builder

RUN apk add --no-cache \
    build-base \
    wget \
    openssl-dev \
    linux-headers \
    coreutils \
    posix-libc-utils

# Prepare directories
RUN mkdir -p /rootfs/data && \
    mkdir -p /rootfs/etc/redis && \
    mkdir -p /rootfs/usr/local/bin && \
    mkdir -p /rootfs/usr/lib && \
    mkdir -p /rootfs/lib && \
    mkdir -p /rootfs/lib64 

# Create User/Group
RUN echo 'root:x:0:0:root:/root:/sbin/nologin' > /rootfs/etc/passwd && \
    echo 'redis:x:999:999:redis:/data:/sbin/nologin' >> /rootfs/etc/passwd && \
    \
    echo 'root:x:0:' > /rootfs/etc/group && \
    echo 'redis:x:999:' >> /rootfs/etc/group


# -----------------------------------------------------------
# 1. Build Redis
# -----------------------------------------------------------
ENV REDIS_VERSION=7.2.4
ENV REDIS_DOWNLOAD_URL=https://github.com/redis/redis/archive/refs/tags/${REDIS_VERSION}.tar.gz

RUN set -eux; \
    wget -qO redis.tar.gz "$REDIS_DOWNLOAD_URL"; \
    mkdir -p /usr/src/redis; \
    tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1; \
    rm redis.tar.gz; \
    make -C /usr/src/redis -j "$(nproc)" BUILD_TLS=yes all; \
    cp /usr/src/redis/src/redis-server /rootfs/usr/local/bin/; \
    strip /rootfs/usr/local/bin/redis-server

# -----------------------------------------------------------
# 2. Config & Init Helper
# -----------------------------------------------------------
# ننسخ الملفات الموجودة عندك أصلاً
COPY redis.conf /rootfs/etc/redis/redis.conf
COPY redis-init.c /usr/src/redis-init.c

# Fix Config paths & permissions inside the image
RUN sed -i 's/^daemonize yes/daemonize no/' /rootfs/etc/redis/redis.conf; \
    sed -i 's/^protected-mode yes/protected-mode no/' /rootfs/etc/redis/redis.conf; \
    sed -i 's/^bind 127.0.0.1 -::1/bind * -::*/' /rootfs/etc/redis/redis.conf; \
    sed -i 's|^pidfile .*|pidfile /data/redis.pid|' /rootfs/etc/redis/redis.conf

# Compile redis-init (From the file we just copied)
RUN gcc -O2 -o /rootfs/usr/local/bin/redis-init /usr/src/redis-init.c && \
    strip /rootfs/usr/local/bin/redis-init

# -----------------------------------------------------------
# 3. Dependencies Copy
# -----------------------------------------------------------
RUN INTERPRETER=$(readelf -l /rootfs/usr/local/bin/redis-server | grep "interpreter" | awk -F': ' '{print $2}' | tr -d ']') && \
    cp "$INTERPRETER" "/rootfs$INTERPRETER" && \
    cp "$INTERPRETER" /rootfs/lib/ && \
    cp "$INTERPRETER" /rootfs/usr/lib/

RUN cp -L /usr/lib/libssl.so* /rootfs/usr/lib/ && \
    cp -L /usr/lib/libcrypto.so* /rootfs/usr/lib/ && \
    cp -L /usr/lib/libgcc_s.so.1 /rootfs/usr/lib/ && \
    find /lib /usr/lib -name "libc.so*" -exec cp -L {} /rootfs/usr/lib/ \; && \
    find /lib /usr/lib -name "libm.so*" -exec cp -L {} /rootfs/usr/lib/ \;

RUN chown -R 999:999 /rootfs/data

# ==========================================
# Stage 2: Final Image
# ==========================================
FROM cgr.dev/chainguard/static:latest

COPY --from=builder /rootfs/etc/passwd /etc/passwd
COPY --from=builder /rootfs/etc/group /etc/group
COPY --from=builder /rootfs/etc/redis/redis.conf /etc/redis/redis.conf

# Binaries
COPY --from=builder /rootfs/usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=builder /rootfs/usr/local/bin/redis-init /usr/local/bin/redis-init

# Libraries
COPY --from=builder /rootfs/usr/lib/ /usr/lib/
COPY --from=builder /rootfs/lib64 /lib64

# Data
COPY --from=builder --chown=999:999 /rootfs/data /data

VOLUME /data
WORKDIR /data
EXPOSE 6379

USER root

ENTRYPOINT ["/usr/local/bin/redis-init"]
CMD ["/etc/redis/redis.conf"]
