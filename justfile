# ==============================================================================
# Project Command Runner
#
# A modern and clean way to manage this project's Docker services.
#
# USAGE:
#   just <recipe> [service]
#
# RECIPES:
#   build [service]    - Build service image(s). (Default: all)
#   run [service]      - Run service container(s). (Default: all)
#   stop [service]     - Stop service container(s). (Default: all)
#   clean [service]    - Clean (stop, remove container & image). (Default: all)
#   logs <service>     - View logs for a running service.
#   ps                 - List running containers for this project.
#   help               - Show this help message.
#
#   dtrack-start       - Start Dependency-Track service for SBOM analysis.
#   dtrack-stop        - Stop Dependency-Track service.
#   dtrack-restart     - Restart Dependency-Track service.
#
# SERVICES:
#   nginx, redis, all
# ==============================================================================

# --- Internal Configuration ---
# Using a project name prefix makes containers unique and easy to find.
# ==============================================================================
# Project Command Runner
# ==============================================================================

export DOCKER_API_VERSION := "1.43"

PROJECT_NAME      := "distroless-project"
NGINX_CONTAINER   := PROJECT_NAME + "-nginx"
REDIS_CONTAINER   := PROJECT_NAME + "-redis"
NGINX_IMAGE       := "my-nginx-app:latest"
REDIS_IMAGE       := "my-redis-app:latest"
REPORTS_DIR       := "./reports"

export SBOM_TOOL   := env_var_or_default("SBOM_TOOL", "trivy")
export SBOM_FORMAT := env_var_or_default("SBOM_FORMAT", "spdx-json")

SBOM_EXTENSION    := if SBOM_FORMAT == "cyclonedx" {
    ".cdx.json"
} else if SBOM_FORMAT == "spdx-json" {
    ".spdx.json"
} else {
    ".json"
}

DTRACK_DIR        := "./dependency-track"
DTRACK_COMPOSE_URL:= "https://dependencytrack.org/docker-compose.yml"
DTRACK_COMPOSE_FILE:= DTRACK_DIR + "/docker-compose.yml"

default: help

help:
    @grep -E '^# ' justfile | cut -c 3-

sbom service='all':
    @echo "--- Generating SBOM ---"
    @echo "   Tool:   {{SBOM_TOOL}}"
    @echo "   Format: {{SBOM_FORMAT}}"
    @if [ "{{service}}" = "all" ] || [ "{{service}}" = "nginx" ]; then \
        echo "=> Processing nginx..."; \
        mkdir -p {{REPORTS_DIR}}/nginx; \
        just _internal-generate-sbom {{NGINX_IMAGE}} "nginx/nginx-sbom"; \
    fi
    @if [ "{{service}}" = "all" ] || [ "{{service}}" = "redis" ]; then \
        echo "=> Processing redis..."; \
        mkdir -p {{REPORTS_DIR}}/redis; \
        just _internal-generate-sbom {{REDIS_IMAGE}} "redis/redis-sbom"; \
    fi
    @echo "Done. SBOMs are organized in sub-directories inside '{{REPORTS_DIR}}'."

_internal-generate-sbom image_name output_filename:
    @if [ "{{SBOM_TOOL}}" = "trivy" ]; then \
        docker run --rm --pull always \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v {{REPORTS_DIR}}:/reports \
          ghcr.io/aquasecurity/trivy:latest \
          image --format {{SBOM_FORMAT}} \
          --output /reports/{{output_filename}}-trivy{{SBOM_EXTENSION}} \
          {{image_name}}; \
    elif [ "{{SBOM_TOOL}}" = "syft" ]; then \
        FMT="{{SBOM_FORMAT}}"; \
        if [ "$FMT" = "cyclonedx" ]; then FMT="cyclonedx-json"; fi; \
        docker run --rm --pull always \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v {{REPORTS_DIR}}:/reports \
          ghcr.io/anchore/syft:latest \
          {{image_name}} -o $FMT \
          > {{REPORTS_DIR}}/{{output_filename}}-syft{{SBOM_EXTENSION}}; \
    else \
        echo "Error: Unknown tool '{{SBOM_TOOL}}'. Use 'trivy' or 'syft'."; \
        exit 1; \
    fi

build service='all':
    @echo "--- Building service(s): {{service}} ---"
    @if [ "{{service}}" = "all" ] || [ "{{service}}" = "nginx" ]; then \
        echo "=> Building nginx image [{{NGINX_IMAGE}}]..."; \
        docker build -t {{NGINX_IMAGE}} ./nginx; \
    fi
    @if [ "{{service}}" = "all" ] || [ "{{service}}" = "redis" ]; then \
        echo "=> Building redis image [{{REDIS_IMAGE}}]..."; \
        docker build -t {{REDIS_IMAGE}} ./redis; \
    fi

run service='all':
    @echo "--- Running service(s): {{service}} ---"
    @if [ "{{service}}" = "all" ] || [ "{{service}}" = "nginx" ]; then \
        echo "=> Starting nginx container [{{NGINX_CONTAINER}}]..."; \
        just _internal-stop {{NGINX_CONTAINER}}; \
        docker run -d --name {{NGINX_CONTAINER}} -p 8080:8080 {{NGINX_IMAGE}}; \
    fi
    @if [ "{{service}}" = "all" ] || [ "{{service}}" = "redis" ]; then \
        echo "=> Starting redis container [{{REDIS_CONTAINER}}]..."; \
        just _internal-stop {{REDIS_CONTAINER}}; \
        docker run -d --name {{REDIS_CONTAINER}} {{REDIS_IMAGE}}; \
    fi
    @echo; just ps

stop service='all':
    @echo "--- Stopping service(s): {{service}} ---"
    @if [ "{{service}}" = "all" ] || [ "{{service}}" = "nginx" ]; then \
        just _internal-stop {{NGINX_CONTAINER}}; \
    fi
    @if [ "{{service}}" = "all" ] || [ "{{service}}" = "redis" ]; then \
        just _internal-stop {{REDIS_CONTAINER}}; \
    fi
    @echo "Stop command complete."

clean service='all':
    @echo "--- Cleaning service(s): {{service}} ---"
    @if [ "{{service}}" = "all" ] || [ "{{service}}" = "nginx" ]; then \
        echo "=> Cleaning up nginx..."; \
        just _internal-stop {{NGINX_CONTAINER}}; \
        docker rmi {{NGINX_IMAGE}} 2>/dev/null || true; \
    fi
    @if [ "{{service}}" = "all" ] || [ "{{service}}" = "redis" ]; then \
        echo "=> Cleaning up redis..."; \
        just _internal-stop {{REDIS_CONTAINER}}; \
        docker rmi {{REDIS_IMAGE}} 2>/dev/null || true; \
    fi
    @echo "Cleanup complete."

logs service:
    @if [ "{{service}}" = "nginx" ]; then \
        echo "--- Tailing logs for {{NGINX_CONTAINER}} (Ctrl+C to stop) ---"; \
        docker logs -f {{NGINX_CONTAINER}}; \
    elif [ "{{service}}" = "redis" ]; then \
        echo "--- Tailing logs for {{REDIS_CONTAINER}} (Ctrl+C to stop) ---"; \
        docker logs -f {{REDIS_CONTAINER}}; \
    else \
        echo "Error: Please specify a valid service (nginx or redis) for logs."; \
        exit 1; \
    fi

ps:
    @echo "--- Listing running project containers ---"
    @docker ps --filter "name={{PROJECT_NAME}}-*"

_internal-stop container_name:
    @docker stop {{container_name}} 2>/dev/null || true
    @docker rm {{container_name}} 2>/dev/null || true

# Start Dependency-Track service
dtrack-start: _dtrack-download _dtrack-patch
	@echo "--- Starting Dependency-Track ---"
	@docker compose -f {{DTRACK_COMPOSE_FILE}} up -d
	@echo "==> Dependency-Track is starting. Frontend will be available at the forwarded port 8080."
	@echo "==> API Server will be at the forwarded port 8081."

# Stop Dependency-Track service
dtrack-stop:
	@echo "--- Stopping Dependency-Track ---"
	@if [ -f {{DTRACK_COMPOSE_FILE}} ]; then \
		docker compose -f {{DTRACK_COMPOSE_FILE}} down; \
	fi
	@echo "--- Dependency-Track stopped ---"

# Restart Dependency-Track service
dtrack-restart: dtrack-stop dtrack-start

# "Private" recipe to download the compose file if it doesn't exist
_dtrack-download:
	@if [ ! -f {{DTRACK_COMPOSE_FILE}} ]; then \
		echo "=> Downloading docker-compose.yml for Dependency-Track..."; \
		mkdir -p {{DTRACK_DIR}}; \
		curl -fsSL {{DTRACK_COMPOSE_URL}} -o {{DTRACK_COMPOSE_FILE}}; \
	fi

# "Private" recipe to patch the compose file for Codespaces and similar environments
_dtrack-patch:
	@# Patch API_BASE_URL only if DTRACK_API_URL is set
	@if [ -n "$$DTRACK_API_URL" ]; then \
		echo "=> Found DTRACK_API_URL. Patching frontend API_BASE_URL..."; \
		yq -i '.services.frontend.environment.API_BASE_URL = strenv(DTRACK_API_URL)' {{DTRACK_COMPOSE_FILE}}; \
	else \
		echo "=> DTRACK_API_URL not set. Skipping API_BASE_URL patch."; \
	fi

	@# Always enable and configure CORS for development environments (Codespaces)
	@echo "=> Enabling CORS in apiserver..."
	@yq -i '.services.apiserver.environment.ALPINE_CORS_ENABLED = "true"' {{DTRACK_COMPOSE_FILE}}
	@yq -i '.services.apiserver.environment.ALPINE_CORS_ALLOW_ORIGIN = "*"' {{DTRACK_COMPOSE_FILE}}
	@yq -i '.services.apiserver.environment.ALPINE_CORS_ALLOW_METHODS = "GET,POST,PUT,DELETE,OPTIONS"' {{DTRACK_COMPOSE_FILE}}
	@yq -i '.services.apiserver.environment.ALPINE_CORS_ALLOW_HEADERS = "*"' {{DTRACK_COMPOSE_FILE}}
	@yq -i '.services.apiserver.environment.ALPINE_CORS_EXPOSE_HEADERS = "*"' {{DTRACK_COMPOSE_FILE}}
