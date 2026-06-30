@echo off
cd /d "%~dp0"
echo ============================================
echo   Hermes + Camofox + SearXNG Setup
echo ============================================
echo.

:: Check prerequisites
where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not installed or not in PATH.
    echo Please install Docker Desktop from https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)

docker compose version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] docker compose not available.
    pause
    exit /b 1
)

echo [OK] Docker and docker compose found.
echo.

:: Create data directories
if not exist "hermes_data\.hermes" mkdir "hermes_data\.hermes"
if not exist "hermes_data\.camofox-docker" mkdir "hermes_data\.camofox-docker"
if not exist "hermes_data\downloads" mkdir "hermes_data\downloads"
if not exist "searxng" mkdir "searxng"

:: Create default config.yaml (prevents first-time setup wizard crash in Docker)
if not exist "hermes_data\.hermes\config.yaml" (
    echo Creating default config.yaml...
    (
		echo approvals:
		echo   mode: smart
        echo web:
        echo   backend: searxng
        echo   search_backend: searxng
        echo   use_gateway: false
        echo browser:
        echo   inactivity_timeout: 120
        echo   command_timeout: 30
        echo   record_sessions: false
        echo   allow_private_urls: false
        echo   engine: auto
        echo   auto_local_for_private_urls: true
        echo   cdp_url: ''
        echo   dialog_policy: must_respond
        echo   dialog_timeout_s: 300
        echo   camofox:
        echo     managed_persistence: true
        echo     user_id: shared-camofox
        echo     session_key: visible-tab
        echo     adopt_existing_tab: true
        echo     rewrite_loopback_urls: false
        echo     loopback_host_alias: host.docker.internal
        echo   cloud_provider: camofox
        echo   use_gateway: false
    ) > "hermes_data\.hermes\config.yaml"
    echo [OK] config.yaml created.
) else (
    echo [SKIP] config.yaml already exists.
)

:: Create placeholder .env (prevents startup failures)
if not exist "hermes_data\.hermes\.env" (
    echo Creating placeholder .env...
    (
        echo CAMOFOX_URL=http://camofox:9377
		echo SEARXNG_URL=http://searxng:8080
        echo.
    ) > "hermes_data\.hermes\.env"
    echo [OK] .env created
) else (
    echo [SKIP] .env already exists.
)
echo.

:: Verify required files (shipped as real files for GitHub, not base64-embedded)
echo Verifying setup files...
if not exist "docker-compose.yml" (
    echo [ERROR] docker-compose.yml not found. All repo files must be in the same folder as this script.
    pause
    exit /b 1
)
if not exist "Dockerfile" (
    echo [ERROR] Dockerfile not found.
    pause
    exit /b 1
)
if not exist "Dockerfile.camofox" (
    echo [ERROR] Dockerfile.camofox not found.
    pause
    exit /b 1
)
echo [OK] All setup files present.
echo.

:: Build and start
echo ============================================
echo   Building and starting containers...
echo ============================================
echo.

docker compose up -d --build

if %errorlevel% equ 0 (
    echo.
    echo ============================================
    echo   All services started!
    echo   Dashboard:  http://localhost:9119
    echo   Camofox:    http://localhost:9377
    echo   SearXNG:    http://localhost:8888
    echo   Camofox VNC: http://localhost:6080/vnc_auto.html?autoconnect=true^&reconnect=true
    echo.
    echo   IMPORTANT: Edit hermes_data\.hermes\.env with your real API key.
    echo ============================================
    echo.
    echo   Fixing SearXNG settings...
    docker compose cp searxng:/etc/searxng/settings.yml settings.yml
    if %errorlevel% neq 0 (echo [WARN] Failed to pull settings.yml from container)
    echo search:>> settings.yml
    echo   formats:>> settings.yml
    echo     - html>> settings.yml
    echo     - json>> settings.yml
    docker compose cp settings.yml searxng:/etc/searxng/settings.yml
    if %errorlevel% neq 0 (echo [WARN] Failed to push settings.yml to container)
    echo [OK] SearXNG settings updated.
    echo   Restarting services to apply fix...
    docker compose down
    docker compose up -d
    echo [OK] Services restarted.
) else (
    echo.
    echo ============================================
    echo   [ERROR] docker compose up failed.
    echo.
    echo   Common issues and fixes:
    echo   1. Docker Desktop not running - start it and retry.
    echo   2. Port conflict - check if ports 9119, 9377, 6080, 8888 are in use.
    echo   3. Build failure - check the build output above for errors.
    echo   4. Try running manually: docker compose up --build
    echo ============================================
)

echo.
pause
