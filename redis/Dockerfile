# =================================================================
# Stage 1: The "Builder"
# Using the latest Debian 13 (trixie) Redis image, which includes jemalloc.
# =================================================================
FROM redis:7-bookworm AS builder


# =================================================================
# Stage 2: The Final "Distroless" Image
# Starting from the Debian 13 distroless base.
# =================================================================
FROM gcr.io/distroless/cc-debian13:nonroot

# Copy OpenSSL 3 libraries, required by this version of Redis
COPY --from=builder /usr/lib/x86_64-linux-gnu/libssl.so.3 /usr/lib/x86_64-linux-gnu/libssl.so.3
COPY --from=builder /usr/lib/x86_64-linux-gnu/libcrypto.so.3 /usr/lib/x86_64-linux-gnu/libcrypto.so.3

# Copy user and group files for correct permissions
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Copy the data directory with correct ownership
COPY --from=builder --chown=redis:redis /data /data

# Copy only the necessary binaries to avoid extra vulnerabilities
COPY --from=builder /usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=builder /usr/local/bin/redis-sentinel /usr/local/bin/redis-sentinel
COPY --from=builder /usr/local/bin/redis-cli /usr/local/bin/redis-cli

# Set the working directory to prevent permission errors
WORKDIR /data

# Expose the default Redis port
EXPOSE 6379

# Set the user to the unprivileged 'redis' user
USER redis

# The command to run the Redis server
CMD ["/usr/local/bin/redis-server"]
