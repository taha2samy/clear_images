# Set the default shell to bash and enable pipefail for robust error handling in RUN instructions.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# = an==============================================================
# Stage 1: The "Builder"
# Uses the official Debian 12 (bookworm) Redis image as a source.
# =================================================================
FROM redis:7-bookworm AS builder

# Temporarily switch to the root user to install dependencies.
USER root

# Install pinned versions of tools, discover dependencies, and then clean up.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libc-bin=2.36-9+deb12u4 \
    gawk=1:5.2.1-2 && \
    mkdir /distroless-deps && \
    # Discover dependencies for the main redis-server binary
    ldd /usr/local/bin/redis-server | awk 'NF == 4 {print $3};' | xargs -I {} cp -v {} /distroless-deps && \
    # Discover dependencies for the optional redis-cli binary
    ldd /usr/local/bin/redis-cli | awk 'NF == 4 {print $3};' | xargs -I {} cp -v {} /distroless-deps && \
    # Clean up build-time tools and apt cache to keep the layer small
    apt-get purge -y --auto-remove libc-bin gawk && \
    rm -rf /var/lib/apt/lists/*

# Revert to the default non-root user before finishing the builder stage.
USER redis


# =================================================================
# Stage 2: The Final "Distroless" Image
# Using Debian 12 base to match the builder stage for library compatibility.
# =================================================================
FROM gcr.io/distroless/cc-debian12:nonroot

# Copy user and group files for the 'redis' user
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Copy all discovered shared libraries from the builder.
COPY --from=builder /distroless-deps/ /lib/x86_64-linux-gnu/

# Copy the Redis server binary
COPY --from=builder /usr/local/bin/redis-server /usr/local/bin/redis-server

# --- Optional Utilities (Commented out for production) ---
# Uncomment the following line if you need debugging capabilities or the HEALTHCHECK.
# COPY --from=builder /usr/local/bin/redis-cli /usr/local/bin/redis-cli

# Copy custom configuration from the build context
COPY --chown=redis:redis redis.conf /data/redis.conf

# Define a volume for data persistence
VOLUME /data

# Set the working directory
WORKDIR /data

# Expose the default Redis port
EXPOSE 6379

# The HEALTHCHECK is commented out as it requires redis-cli.
# HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
#   CMD ["/usr/local/bin/redis-cli", "ping"]

# Switch to the unprivileged 'redis' user for the final image
USER redis

# Set the entrypoint and default command for flexible execution
ENTRYPOINT ["/usr/local/bin/redis-server"]
CMD ["/data/redis.conf"]