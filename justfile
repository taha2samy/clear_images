# ==============================================================================
# Project Command Runner
#
# A modern and clean way to manage this project's Docker services.
#
# USAGE:
#   just <recipe> [service]
#
# RECIPES:
#   build [service]   - Build a service image (default: all).
#   run [service]     - Run a service container (default: all).
#   stop [service]    - Stop a service container (default: all).
#   clean [service]   - Clean (stop and remove) a service image (default: all).
#   logs <service>    - View logs for a running service.
#   ps                - List running containers for this project.
#   help              - Show this help message.
#
# SERVICES:
#   nginx
#   redis
# ==============================================================================

# --- Configuration ---
NGINX_IMAGE := "my-nginx-app:latest"
REDIS_IMAGE := "my-redis-app:latest"

# --- Recipes (Commands) ---

# Default recipe to show help
default: help

# Show the help message
help:
    @grep -E '^# ' justfile | cut -c 3-

# Build a specific service image, or all if none is specified
build service:
    @echo "--- Building service(s)... ---"
    @if [ -z "{{service}}" ] || [ "{{service}}" = "all" ] || [ "{{service}}" = "nginx" ]; then \
        echo "Building nginx..."; \
        docker build -t {{NGINX_IMAGE}} ./nginx; \
    fi
    @if [ -z "{{service}}" ] || [ "{{service}}" = "all" ] || [ "{{service}}" = "redis" ]; then \
        echo "Building redis..."; \
        docker build -t {{REDIS_IMAGE}} ./redis; \
    fi

# Run a specific service container, or all
run service:
    @echo "--- Running service(s)... ---"
    @if [ -z "{{service}}" ] || [ "{{service}}" = "all" ] || [ "{{service}}" = "nginx" ]; then \
        echo "Starting nginx (ensuring clean state)..."; \
        just _internal_stop nginx; \
        docker run -d --name nginx -p 8080:8080 {{NGINX_IMAGE}}; \
    fi
    @if [ -z "{{service}}" ] || [ "{{service}}" = "all" ] || [ "{{service}}" = "redis" ]; then \
        echo "Starting redis (ensuring clean state)..."; \
        just _internal_stop redis; \
        docker run -d --name redis {{REDIS_IMAGE}}; \
    fi
    @echo; just ps

# Stop a specific service container, or all (user-facing, verbose)
stop service:
    @echo "--- Stopping service(s)... ---"
    @just _internal_stop {{service}}
    @echo "Stop command complete."

# Clean (stop container and remove image) for a service, or all
clean service:
    @echo "--- Cleaning service(s)... ---"
    @just _internal_stop {{service}}
    @if [ -z "{{service}}" ] || [ "{{service}}" = "all" ] || [ "{{service}}" = "nginx" ]; then \
        echo "Removing nginx image..."; \
        docker rmi {{NGINX_IMAGE}} > /dev/null 2>&1 || true; \
    fi
    @if [ -z "{{service}}" ] || [ "{{service}}" = "all" ] || [ "{{service}}" = "redis" ]; then \
        echo "Removing redis image..."; \
        docker rmi {{REDIS_IMAGE}} > /dev/null 2>&1 || true; \
    fi
    @echo "Cleanup complete."

# View logs for a specific, running service (this parameter is required)
logs service:
    @echo "--- Tailing logs for {{service}} (Ctrl+C to stop) ---"
    @docker logs -f {{service}}

# List running containers for this project
ps:
    @echo "--- Listing running project containers ---"
    @docker ps --filter "name=nginx" --filter "name=redis"

# This is a "private" recipe for internal use. It produces no output.
# The leading underscore is a convention to indicate it's not for direct user calls.
_internal_stop service:
    @if [ -z "{{service}}" ] || [ "{{service}}" = "all" ] || [ "{{service}}" = "nginx" ]; then \
        docker stop nginx > /dev/null 2>&1 || true; \
        docker rm nginx > /dev/null 2>&1 || true; \
    fi
    @if [ -z "{{service}}" ] || [ "{{service}}" = "all" ] || [ "{{service}}" = "redis" ]; then \
        docker stop redis > /dev/null 2>&1 || true; \
        docker rm redis > /dev/null 2>&1 || true; \
    fi