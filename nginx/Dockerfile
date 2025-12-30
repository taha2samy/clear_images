FROM nginxinc/nginx-unprivileged:1.27-bookworm AS builder

USER root

RUN mkdir /nginx-libs && \
    ldd /usr/sbin/nginx | awk 'NF==4{print $3}' | grep -v '^$' | sort -u | \
    xargs -r cp --parents -t /nginx-libs/ || true

RUN ldd -r /usr/sbin/nginx 2>/dev/null | awk 'NF==4{print $3}' | grep -v '^$' | sort -u | \
    xargs -r cp --parents -t /nginx-libs/ || true

RUN readelf -d /usr/sbin/nginx | grep NEEDED | awk '{print $5}' | grep -v '^$' | \
    xargs -I {} find /lib /lib64 /usr/lib -name {} 2>/dev/null | grep -v '^$' | \
    sort -u | xargs -r cp --parents -t /nginx-libs/ || true

RUN mkdir -p /runtime-dirs/var/log/nginx \
             /runtime-dirs/var/cache/nginx \
             /runtime-dirs/var/run && \
    chown -R 101:101 /runtime-dirs && \
    ln -sf /dev/stdout /runtime-dirs/var/log/nginx/access.log && \
    ln -sf /dev/stderr /runtime-dirs/var/log/nginx/error.log && \
    touch /runtime-dirs/var/run/nginx.pid && \
    chown 101:101 /runtime-dirs/var/run/nginx.pid

USER nginx

FROM gcr.io/distroless/cc-debian12:nonroot

COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

COPY --from=builder /nginx-libs /
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/lib/nginx /usr/lib/nginx
COPY --from=builder /usr/share/nginx/html /usr/share/nginx/html

COPY --from=builder --chown=101:101 /runtime-dirs/var /var

COPY nginx.conf /etc/nginx/nginx.conf

USER 101:101

EXPOSE 8080
VOLUME ["/var/cache/nginx", "/var/log/nginx"]
ENTRYPOINT ["/usr/sbin/nginx"]
CMD ["-g", "daemon off;"]
