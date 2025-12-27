# =================================================================
# Stage 1: The "Builder"
# Using a Debian-based (glibc) unprivileged Nginx image.
# =================================================================
FROM nginxinc/nginx-unprivileged:1.27-bookworm AS builder


# =================================================================
# Stage 2: The Final "Distroless" Image
# Starting from a minimal base with glibc and common C libraries.
# =================================================================
FROM gcr.io/distroless/cc-debian13:nonroot

# Copy user and group files to run as the 'nginx' user
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Copy the Nginx binary itself
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx

# Copy configuration, modules, and required libraries
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/lib/nginx /usr/lib/nginx

# =================================================================
# THE FINAL FIX IS HERE: Copy the missing shared libraries
# =================================================================
COPY --from=builder /lib/x86_64-linux-gnu/libcrypt.so.1 /lib/x86_64-linux-gnu/libcrypt.so.1
COPY --from=builder /lib/x86_64-linux-gnu/libpcre2-8.so.0 /lib/x86_64-linux-gnu/libpcre2-8.so.0

# Copy required runtime directories for logs and cache
COPY --from=builder --chown=nginx:nginx /var/log/nginx /var/log/nginx
COPY --from=builder --chown=nginx:nginx /var/cache/nginx /var/cache/nginx
COPY --from=builder /tmp /tmp

# Copy the actual web content for your site
COPY index.html /usr/share/nginx/html/index.html

# Expose the non-privileged port
EXPOSE 8080

USER nginx

# The command to run Nginx in the foreground
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]