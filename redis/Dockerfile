FROM cgr.dev/chainguard/wolfi-base AS builder

# 1. Install Build Dependencies & Tools
RUN apk add --no-cache \
    build-base wget openssl-dev linux-headers binutils scanelf coreutils

# 2. Install lddtree 
RUN wget -qO /usr/bin/lddtree https://raw.githubusercontent.com/ncopa/lddtree/master/lddtree.sh && \
    chmod +x /usr/bin/lddtree

# 3. Build Redis from Source
ENV REDIS_VERSION=7.2.4
ENV REDIS_DOWNLOAD_URL=http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz

RUN set -eux; \
    wget -qO redis.tar.gz "$REDIS_DOWNLOAD_URL"; \
    mkdir -p /usr/src/redis; \
    tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1; \
    make -C /usr/src/redis -j "$(nproc)" all; \
    make -C /usr/src/redis install; \
    strip /usr/local/bin/redis-server

# 4. Compile the Custom Init Helper (Static Build)
COPY redis-init.c /usr/src/redis-init.c
RUN gcc -static -O2 -o /usr/local/bin/redis-init /usr/src/redis-init.c && \
    chmod +x /usr/local/bin/redis-init

RUN mkdir -p /distroless-deps && \
    lddtree /usr/local/bin/redis-server | awk '{print $NF}' | grep -E '\.so' | sort -u | \
    xargs -I {} cp -L {} /distroless-deps/ && \
    # Copy the dynamic linker/loader
    INTERPRETER=$(readelf -l /usr/local/bin/redis-server | grep "interpreter" | awk -F': ' '{print $2}' | tr -d ']') && \
    cp -L "$INTERPRETER" /distroless-deps/

# 6. Prepare User/Group files (Wolfi format)
RUN echo 'root:x:0:0:root:/root:/sbin/nologin' > /distroless-deps/passwd && \
    echo 'redis:x:999:999:redis:/data:/sbin/nologin' >> /distroless-deps/passwd && \
    echo 'root:x:0:' > /distroless-deps/group && \
    echo 'redis:x:999:' >> /distroless-deps/group

# =================================================================
# Stage 2: The Final "Distroless" Image
# =================================================================
FROM cgr.dev/chainguard/static:latest

# Copy User/Group
COPY --from=builder /distroless-deps/passwd /etc/passwd
COPY --from=builder /distroless-deps/group /etc/group

COPY --from=builder /distroless-deps/ /usr/lib/
COPY --from=builder /distroless-deps/ld-linux* /lib/

# Copy Binaries
COPY --from=builder /usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=builder /usr/local/bin/redis-init /usr/local/bin/redis-init

# Copy Config
COPY --chown=999:999 redis.conf /data/redis.conf

# Setup Environment
VOLUME /data
WORKDIR /data
EXPOSE 6379

# Entrypoint via Custom Init
USER root
ENTRYPOINT ["/usr/local/bin/redis-init"]
CMD ["/data/redis.conf"]
