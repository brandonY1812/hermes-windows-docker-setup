#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")"

echo "============================================"
echo "  Hermes + Camofox + SearXNG Setup"
echo "============================================"
echo

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "[WARN] This setup script is tested on macOS."
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] Docker is not installed or not in PATH."
    echo "Install Docker Desktop from https://www.docker.com/products/docker-desktop/"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "[ERROR] docker compose is not available."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "[ERROR] Docker Desktop is installed but not running."
    echo "Start Docker Desktop, wait until it is ready, and run this script again."
    exit 1
fi

echo "[OK] Docker and docker compose are ready."
echo

required_files=(
    "docker-compose.yml"
    "Dockerfile"
    "Dockerfile.camofox"
    "config.yaml"
    ".env"
)

echo "Verifying setup files..."
for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "[ERROR] $file not found. All repository files must be in the same folder as this script."
        exit 1
    fi
done
echo "[OK] All setup files are present."
echo

mkdir -p \
    "hermes_data/.hermes" \
    "hermes_data/.camofox-docker" \
    "hermes_data/downloads" \
    "searxng"

if [[ ! -f "hermes_data/.hermes/config.yaml" ]]; then
    cp "config.yaml" "hermes_data/.hermes/config.yaml"
    echo "[OK] config.yaml copied."
else
    echo "[SKIP] config.yaml already exists."
fi

if [[ ! -f "hermes_data/.hermes/.env" ]]; then
    cp ".env" "hermes_data/.hermes/.env"
    echo "[OK] .env copied."
else
    echo "[SKIP] .env already exists."
fi
echo

echo "============================================"
echo "  Building and starting containers..."
echo "============================================"
echo

docker compose up -d --build

echo
echo "Fixing SearXNG settings..."
settings_file="$(mktemp -t hermes-searxng-settings.XXXXXX)"
trap 'rm -f "$settings_file"' EXIT

if docker compose cp searxng:/etc/searxng/settings.yml "$settings_file"; then
    if grep -Eq '^[[:space:]]*-[[:space:]]+json([[:space:]]*(#.*)?)?$' "$settings_file"; then
        echo "[SKIP] SearXNG JSON output is already enabled."
    else
        cat >>"$settings_file" <<'EOF'

search:
  formats:
    - html
    - json
EOF
        docker compose cp "$settings_file" searxng:/etc/searxng/settings.yml
        echo "[OK] SearXNG JSON output enabled."
        docker compose restart searxng
    fi
else
    echo "[WARN] Could not read SearXNG settings; JSON search output may be unavailable."
fi

echo
docker compose ps
echo
echo "============================================"
echo "  All services started!"
echo "  Dashboard:       http://localhost:9119"
echo "  Camofox CDP:     http://localhost:9377"
echo "  SearXNG:         http://localhost:8888"
echo "  Camofox VNC:     http://localhost:6080/"
echo "  Hermes Router:   http://localhost:8319"
echo
echo "  IMPORTANT: Edit hermes_data/.hermes/.env with your real API keys."
echo "============================================"
