# ==========================================
# Stage 1: Builder
# ==========================================
FROM cgr.dev/chainguard/wolfi-base AS builder

# 1. Install Dependencies
RUN apk add --no-cache \
    build-base \
    wget \
    openssl-dev \
    pcre-dev \
    zlib-dev \
    linux-headers \
    coreutils \
    posix-libc-utils \
    gd-dev \
    libxml2-dev \
    libxslt-dev

# 2. Prepare RootFS Structure
RUN mkdir -p /rootfs/var/log/nginx && \
    mkdir -p /rootfs/var/cache/nginx && \
    mkdir -p /rootfs/var/run && \
    mkdir -p /rootfs/etc/nginx && \
    mkdir -p /rootfs/usr/sbin && \
    mkdir -p /rootfs/usr/lib/nginx/modules && \
    mkdir -p /rootfs/usr/lib && \
    mkdir -p /rootfs/lib && \
    mkdir -p /rootfs/lib64 && \
    mkdir -p /rootfs/tmp

# 3. Create Nginx User/Group
RUN echo 'root:x:0:0:root:/root:/sbin/nologin' > /rootfs/etc/passwd && \
    echo 'nginx:x:101:101:nginx:/var/cache/nginx:/sbin/nologin' >> /rootfs/etc/passwd && \
    echo 'root:x:0:' > /rootfs/etc/group && \
    echo 'nginx:x:101:' >> /rootfs/etc/group

# 4. Build Nginx
ENV NGINX_VERSION=1.25.3
RUN set -eux; \
    wget -qO nginx.tar.gz "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"; \
    tar -xzf nginx.tar.gz; \
    cd nginx-${NGINX_VERSION}; \
    \
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-compat \
        --with-file-aio \
        --with-threads \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_realip_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_slice_module \
        --with-http_stub_status_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_realip_module \
        --with-cc-opt="-Wno-error"; \
    \
    make -j "$(nproc)"; \
    make install; \
    \
    # Copy Installed Files to RootFS
    cp /usr/sbin/nginx /rootfs/usr/sbin/; \
    strip /rootfs/usr/sbin/nginx; \
    cp -r /etc/nginx/* /rootfs/etc/nginx/; \
    \
    # === [ هنا التعديل المهم لظهور اللوجز ] ===
    # نربط ملفات اللوج بـ stdout/stderr عشان تظهر في Docker logs
    ln -sf /dev/stdout /rootfs/var/log/nginx/access.log; \
    ln -sf /dev/stderr /rootfs/var/log/nginx/error.log

# 5. Dependency Hunting
RUN INTERPRETER=$(readelf -l /rootfs/usr/sbin/nginx | grep "interpreter" | awk -F': ' '{print $2}' | tr -d ']') && \
    cp "$INTERPRETER" "/rootfs$INTERPRETER" && \
    cp "$INTERPRETER" /rootfs/lib/ && \
    cp "$INTERPRETER" /rootfs/usr/lib/

RUN cp -L /usr/lib/libssl.so* /rootfs/usr/lib/ && \
    cp -L /usr/lib/libcrypto.so* /rootfs/usr/lib/ && \
    cp -L /usr/lib/libpcre*.so* /rootfs/usr/lib/ && \
    cp -L /usr/lib/libz.so* /rootfs/usr/lib/ && \
    cp -L /usr/lib/libgcc_s.so.1 /rootfs/usr/lib/ && \
    find /lib /usr/lib -name "libc.so*" -exec cp -L {} /rootfs/usr/lib/ \; && \
    find /lib /usr/lib -name "libm.so*" -exec cp -L {} /rootfs/usr/lib/ \; && \
    find /lib /usr/lib -name "libcrypt.so*" -exec cp -L {} /rootfs/usr/lib/ \;

RUN chown -R 101:101 /rootfs/var/log/nginx && \
    chown -R 101:101 /rootfs/var/cache/nginx && \
    chown -R 101:101 /rootfs/var/run && \
    chown -R 101:101 /rootfs/etc/nginx

# ==========================================
# Stage 2: Final Image
# ==========================================
FROM cgr.dev/chainguard/static:latest

COPY --from=builder /rootfs/etc/passwd /etc/passwd
COPY --from=builder /rootfs/etc/group /etc/group
COPY --from=builder /rootfs/usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /rootfs/etc/nginx /etc/nginx
COPY --from=builder /rootfs/usr/lib/ /usr/lib/
COPY --from=builder /rootfs/lib64 /lib64
COPY --from=builder --chown=101:101 /rootfs/var/log/nginx /var/log/nginx
COPY --from=builder --chown=101:101 /rootfs/var/cache/nginx /var/cache/nginx
COPY --from=builder --chown=101:101 /rootfs/var/run /var/run

EXPOSE 80 443
STOPSIGNAL SIGQUIT
USER nginx

CMD ["nginx", "-g", "daemon off;"]
