# =========================================================================
# Stage 1: The Builder
# =========================================================================
FROM nginxinc/nginx-unprivileged:1.27-bookworm AS builder

USER root

RUN apt-get update && apt-get install -y pax-utils --no-install-recommends

RUN mkdir /gathered-libs
RUN ( \
        lddtree -l /usr/sbin/nginx; \
        ldd -r /usr/sbin/nginx 2>/dev/null | awk 'NF==4{print $3}'; \
    ) | grep '^/' | sort -u | xargs -r cp --parents -t /gathered-libs/

RUN mkdir -p /runtime-dirs/var/cache/nginx /runtime-dirs/var/log/nginx && \
    ln -sf /dev/stdout /runtime-dirs/var/log/nginx/access.log && \
    ln -sf /dev/stderr /runtime-dirs/var/log/nginx/error.log && \
    chown -R 101:101 /runtime-dirs/var

RUN apt-get purge -y --auto-remove pax-utils && rm -rf /var/lib/apt/lists/*

# =========================================================================
# Stage 2: The Final CC Image
# =========================================================================
FROM gcr.io/distroless/cc-debian12

COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

COPY --from=builder /gathered-libs/ /
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/lib/nginx /usr/lib/nginx
COPY --from=builder /usr/share/nginx/html /usr/share/nginx/html
COPY --from=builder --chown=101:101 /runtime-dirs/var /var

USER 101:101

EXPOSE 8080

ENTRYPOINT ["/usr/sbin/nginx"]

CMD ["-g", "daemon off;"]