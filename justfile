
PROJECT_NAME := "distroless-project"
REPORTS_DIR  := "./reports"

# Add new services here (space separated)
SERVICES := "nginx redis super-nginx super-redis"

# Dependency Track
DTRACK_DIR          := "./dependency-track"
DTRACK_COMPOSE_URL  := "https://dependencytrack.org/docker-compose.yml"
DTRACK_COMPOSE_FILE := DTRACK_DIR + "/docker-compose.yml"

# SBOM Configuration
export SBOM_TOOL   := env_var_or_default("SBOM_TOOL", "trivy")
export SBOM_FORMAT := env_var_or_default("SBOM_FORMAT", "spdx-json")

SBOM_EXTENSION := if SBOM_FORMAT == "cyclonedx" { ".cdx.json" } else if SBOM_FORMAT == "spdx-json" { ".spdx.json" } else { ".json" }

default: help


# Read the help message from the external text file
help:
    @cat HELP.txt

build service='all':
    #!/usr/bin/env sh
    TARGETS="{{SERVICES}}"
    if [ "{{service}}" != "all" ]; then TARGETS="{{service}}"; fi
    for s in $TARGETS; do
        echo "=> Building $s..."
        docker build -t "{{PROJECT_NAME}}-$s" "./$s"
    done




run service='all' args='':
    #!/usr/bin/env sh
    TARGETS="{{SERVICES}}"
    if [ "{{service}}" != "all" ]; then TARGETS="{{service}}"; fi
    
    for s in $TARGETS; do
        echo "=> Starting $s with args: {{args}}..."
        just _internal-stop "{{PROJECT_NAME}}-$s"
        
        # Run command: Name + User Args + Image
        docker run -d --name "{{PROJECT_NAME}}-$s" {{args}} "{{PROJECT_NAME}}-$s"
    done
    echo ""
    just ps



stop service='all':
    #!/usr/bin/env sh
    TARGETS="{{SERVICES}}"
    if [ "{{service}}" != "all" ]; then TARGETS="{{service}}"; fi
    for s in $TARGETS; do
        just _internal-stop "{{PROJECT_NAME}}-$s"
    done
    echo "Stop command complete."

clean service='all':
    #!/usr/bin/env sh
    TARGETS="{{SERVICES}}"
    if [ "{{service}}" != "all" ]; then TARGETS="{{service}}"; fi
    for s in $TARGETS; do
        echo "=> Cleaning $s..."
        just _internal-stop "{{PROJECT_NAME}}-$s"
        docker rmi "{{PROJECT_NAME}}-$s" 2>/dev/null || true
    done
    echo "Cleanup complete."

sbom service='all':
    #!/usr/bin/env sh
    TARGETS="{{SERVICES}}"
    if [ "{{service}}" != "all" ]; then TARGETS="{{service}}"; fi
    echo "--- Generating SBOM (Tool: {{SBOM_TOOL}}) ---"
    mkdir -p {{REPORTS_DIR}}
    for s in $TARGETS; do
        echo "=> Processing $s..."
        mkdir -p "{{REPORTS_DIR}}/$s"
        just _internal-generate-sbom "{{PROJECT_NAME}}-$s" "$s/$s-sbom"
    done
    echo "Done."

logs service:
    @echo "--- Tailing logs for {{PROJECT_NAME}}-{{service}} ---"
    @docker logs -f "{{PROJECT_NAME}}-{{service}}"

ps:
    @echo "--- Listing running project containers ---"
    @docker ps --filter "name={{PROJECT_NAME}}-*"

_internal-stop container_name:
    @docker stop {{container_name}} 2>/dev/null || true
    @docker rm {{container_name}} 2>/dev/null || true

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
          ghcr.io/anchore/syft:latest \
          {{image_name}} -o $FMT \
          > {{REPORTS_DIR}}/{{output_filename}}-syft{{SBOM_EXTENSION}}; \
    fi




# Start Dependency-Track service
dtrack-start: _dtrack-download _dtrack-patch
    @echo "--- Starting Dependency-Track ---"
    @docker compose -f {{DTRACK_COMPOSE_FILE}} up -d
    @echo "----------------------------------------------------------------"
    @if [ -n "$$CODESPACE_NAME" ]; then \
        echo "==> Environment: GitHub Codespaces"; \
        echo "==> Frontend URL: https://$${CODESPACE_NAME}-8080.$${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"; \
        echo "==> API URL:      https://$${CODESPACE_NAME}-8081.$${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"; \
    else \
        echo "==> Environment: Localhost"; \
        echo "==> Frontend URL: http://localhost:8080"; \
        echo "==> API URL:      http://localhost:8081"; \
    fi
    @echo "----------------------------------------------------------------"


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
    #!/usr/bin/env bash
    set -e
    COMPOSE_FILE="{{DTRACK_COMPOSE_FILE}}"
    
    # 1. Handle API_BASE_URL
    if [ -z "$DTRACK_API_URL" ] && [ -n "$CODESPACE_NAME" ]; then
        DETECTED_URL="https://$CODESPACE_NAME-8081.$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN"
        echo "=> Auto-detected Codespaces API URL: $DETECTED_URL"
        yq -i ".services.frontend.environment.API_BASE_URL = \"$DETECTED_URL\"" "$COMPOSE_FILE"
    elif [ -n "$DTRACK_API_URL" ]; then
        echo "=> Using provided DTRACK_API_URL: $DTRACK_API_URL"
        yq -i ".services.frontend.environment.API_BASE_URL = \"$DTRACK_API_URL\"" "$COMPOSE_FILE"
    else
        echo "=> No specific API URL detected. Defaulting to localhost config."
    fi

    # 2. Ensure CORS is enabled
    echo "=> Ensuring CORS is enabled..."
    yq -i '.services.apiserver.environment.ALPINE_CORS_ENABLED = "true"' "$COMPOSE_FILE"
    
    # 3. Set Origin to * only if missing
    CURRENT_ORIGIN=$(yq '.services.apiserver.environment.ALPINE_CORS_ALLOW_ORIGIN' "$COMPOSE_FILE")
    if [ "$CURRENT_ORIGIN" = "null" ] || [ -z "$CURRENT_ORIGIN" ]; then
        echo "=> Setting default CORS Origin to *"
        yq -i '.services.apiserver.environment.ALPINE_CORS_ALLOW_ORIGIN = "*"' "$COMPOSE_FILE"
    fi

dtrack-add-trivy:
    #!/usr/bin/env bash
    set -e
    COMPOSE_FILE="{{DTRACK_COMPOSE_FILE}}"
    TRIVY_TOKEN="MySecretTrivyToken"

    echo "=> Checking if Trivy service exists..."
    
    # Check if trivy service is missing
    if [ "$(yq '.services.trivy' "$COMPOSE_FILE")" = "null" ]; then
        echo "=> Trivy service not found. Injecting configuration..."
        
        # 1. Add the Trivy Service directly using yq env injection
        # We construct the object incrementally to avoid EOF indentation issues
        export T_TOKEN="$TRIVY_TOKEN"
        
        yq -i '.services.trivy.image = "aquasec/trivy:latest"' "$COMPOSE_FILE"
        yq -i '.services.trivy.command = "server --listen :8080 --token " + strenv(T_TOKEN)' "$COMPOSE_FILE"
        yq -i '.services.trivy.ports = ["8085:8080"]' "$COMPOSE_FILE"
        yq -i '.services.trivy.volumes = ["trivy-cache:/root/.cache/trivy"]' "$COMPOSE_FILE"
        yq -i '.services.trivy.restart = "unless-stopped"' "$COMPOSE_FILE"
        
        # 2. Add the Volume
        yq -i '.volumes.trivy-cache = {}' "$COMPOSE_FILE"
        
        echo "=> Trivy service injected successfully."
        echo "=> NOTE: Use Token '$TRIVY_TOKEN' and URL 'http://trivy:8080' in Dependency-Track settings."
    else
        echo "=> Trivy service already exists. Skipping injection."
    fi
