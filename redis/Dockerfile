# =================================================================
# Stage 1: The "Builder"
# Uses the official Redis image to source all necessary files.
# =================================================================
FROM redis:7-bookworm AS builder


# =================================================================
# Stage 2: The Final "Distroless" Image
# Starts from a minimal base and copies only essential artifacts.
# =================================================================
FROM gcr.io/distroless/cc-debian12:nonroot

# Copy required system libraries from the builder stage
COPY --from=builder /usr/lib/x86_64-linux-gnu/libssl.so.3 /usr/lib/x8-64-linux-gnu/libssl.so.3
COPY --from=builder /usr/lib/x86_64-linux-gnu/libcrypto.so.3 /usr/lib/x86_64-linux-gnu/libcrypto.so.3

# Copy user and group files for correct permissions
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Copy application data and essential binaries with correct ownership
COPY --from=builder --chown=redis:redis /data /data
COPY --from=builder /usr/local/bin/redis-server /usr/local/bin/redis-server

# --- Optional Utilities ---
# The following binaries are commented out for a minimal production image.
# Uncomment them if you need debugging or specific features.

# redis-sentinel is not needed for a standalone server instance.
# COPY --from=builder /usr/local/bin/redis-sentinel /usr/local/bin/redis-sentinel

# redis-cli is useful for debugging but increases the attack surface.
# COPY --from=builder /usr/local/bin/redis-cli /usr/local/bin/redis-cli

# Copy custom configuration from the build context
COPY --chown=redis:redis redis.conf /data/redis.conf

# Define a volume for data persistence
VOLUME /data

# Set the working directory
WORKDIR /data

# Expose the default Redis port
EXPOSE 6379

# The HEALTHCHECK is disabled as it requires redis-cli. Uncomment if you enable redis-cli.
# HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
#   CMD ["/usr/local/bin/redis-cli", "ping"]

# Switch to the unprivileged 'redis' user
USER redis

# Set the entrypoint and default command for flexible execution
ENTRYPOINT ["/usr/local/bin/redis-server"]
CMD ["/data/redis.conf"]