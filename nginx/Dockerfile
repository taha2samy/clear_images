# =================================================================
# Stage 1: The "Builder"
# Uses an unprivileged Debian 12 (bookworm) Nginx image as a source.
# =================================================================
FROM nginxinc/nginx-unprivileged:1.27-bookworm AS builder

# Temporarily switch to the root user to install dependencies.
# This is safe as it's only within this throwaway builder stage.
USER root

# Install necessary tools, discover dependencies, then clean up.
RUN apt-get update && apt-get install -y --no-install-recommends libc-bin gawk && \
    mkdir /distroless-deps && \
    ldd /usr/sbin/nginx | awk 'NF == 4 {print $3};' | xargs -I {} cp -v {} /distroless-deps && \
    rm -rf /var/lib/apt/lists/*

USER nginx


# =================================================================
# Stage 2: The Final "Distroless" Image
# Using Debian 12 base to match the builder stage for library compatibility.
# =================================================================
FROM gcr.io/distroless/cc-debian12:nonroot

# Copy user and group files for the 'nginx' user
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Copy all discovered shared libraries from the builder
COPY --from=builder /distroless-deps/ /lib/x86_64-linux-gnu/

# Copy the Nginx binary itself
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx

# Copy configuration, modules, and default web content
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/lib/nginx /usr/lib/nginx
COPY --from=builder /usr/share/nginx/html /usr/share/nginx/html

# Copy required runtime directories with correct ownership
COPY --from=builder --chown=nginx:nginx /var/log/nginx /var/log/nginx
COPY --from=builder --chown=nginx:nginx /var/cache/nginx /var/cache/nginx

# Expose the non-privileged port (default in unprivileged image is 8080)
EXPOSE 8080

# Switch to the unprivileged user for the final image
USER nginx
VOLUME /var/cache/nginx /var/log/nginx

# Set the entrypoint and default command for flexible execution
ENTRYPOINT ["/usr/sbin/nginx"]
CMD ["-g", "daemon off;"]