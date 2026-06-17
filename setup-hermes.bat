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

:: Write files from embedded base64

echo [1/4] Writing docker-compose.yml...
powershell -NoProfile -Command "[IO.File]::WriteAllBytes('docker-compose.yml', [Convert]::FromBase64String('c2VydmljZXM6CiAgaGVybWVzOgogICAgYnVpbGQ6IC4KICAgIGNvbnRhaW5lcl9uYW1lOiBoZXJtZXMKICAgIHJlc3RhcnQ6IHVubGVzcy1zdG9wcGVkCiAgICBtZW1fbGltaXQ6IDRnCiAgICBjcHVzOiAyLjAKICAgIHN0ZGluX29wZW46IHRydWUKICAgIHR0eTogdHJ1ZQogICAgY29tbWFuZDogWyJnYXRld2F5IiwgInJ1biJdCiAgICBwb3J0czoKICAgICAgLSAiOTExOTo5MTE5IgogICAgZW52aXJvbm1lbnQ6CiAgICAgIC0gSEVSTUVTX0hPTUU9L29wdC9kYXRhCiAgICAgIC0gSEVSTUVTX0RBU0hCT0FSRD0xCiAgICAgIC0gSEVSTUVTX0RBU0hCT0FSRF9JTlNFQ1VSRT0xICMgQnlwYXNzZXMgT0F1dGggcG9ydGFsIGZvciB0cnVzdGVkIGhvc3QgYWNjZXNzCiAgICB2b2x1bWVzOgogICAgICAtIC5caGVybWVzX2RhdGFcLmhlcm1lczovb3B0L2RhdGEKICAgICAgLSAuXGhlcm1lc19kYXRhXGRvd25sb2Fkczovb3B0L2Rvd25sb2FkcwogICAgbmV0d29ya3M6CiAgICAgIC0gaGVybWVzX25ldAogICAgZGVwZW5kc19vbjoKICAgICAgY2Ftb2ZveDoKICAgICAgICBjb25kaXRpb246IHNlcnZpY2Vfc3RhcnRlZAogICAgICBzZWFyeG5nOgogICAgICAgIGNvbmRpdGlvbjogc2VydmljZV9zdGFydGVkCgogIGNhbW9mb3g6CiAgICBidWlsZDoKICAgICAgY29udGV4dDogLiAgICAgICAgICAgICAgICAgICAgICAgICMgU3BlY2lmaWVzIHRoZSBmb2xkZXIgd2hlcmUgdGhlIGZpbGUgbGl2ZXMgKGN1cnJlbnQgZGlyZWN0b3J5KQogICAgICBkb2NrZXJmaWxlOiBEb2NrZXJmaWxlLmNhbW9mb3ggICAgIyBQb2ludHMgZXhwbGljaXRseSB0byB5b3VyIGN1c3RvbSBuYW1lZCBmaWxlCiAgICBjb250YWluZXJfbmFtZTogY2Ftb2ZveAogICAgcmVzdGFydDogdW5sZXNzLXN0b3BwZWQKICAgIHBvcnRzOgogICAgICAtICI5Mzc3OjkzNzciCiAgICAgIC0gIjYwODA6NjA4MCIKICAgIGVudmlyb25tZW50OgogICAgICAtIENBTU9GT1hfUE9SVD05Mzc3CiAgICAgIC0gVk5DX0JJTkQ9MC4wLjAuMAogICAgICAtIFZOQ19SRVNPTFVUSU9OPTE5MjB4MTA4MAogICAgICAtIENBTU9GT1hfSEVBRExFU1M9dmlydHVhbAogICAgdm9sdW1lczoKICAgICAgLSAuXGhlcm1lc19kYXRhXC5jYW1vZm94LWRvY2tlcjovcm9vdC8uY2Ftb2ZveAogICAgICAtIC5caGVybWVzX2RhdGFcZG93bmxvYWRzOi90bXAKICAgIG5ldHdvcmtzOgogICAgICAtIGhlcm1lc19uZXQKCiAgc2VhcnhuZzoKICAgIGltYWdlOiBzZWFyeG5nL3NlYXJ4bmc6bGF0ZXN0CiAgICBjb250YWluZXJfbmFtZTogc2VhcnhuZwogICAgcmVzdGFydDogdW5sZXNzLXN0b3BwZWQKICAgIHBvcnRzOgogICAgICAtICI4ODg4OjgwODAiCiAgICB2b2x1bWVzOgogICAgICAtIC5cc2VhcnhuZzovZXRjL3NlYXJ4bmc6cncKICAgIG5ldHdvcmtzOgogICAgICAtIGhlcm1lc19uZXQKCm5ldHdvcmtzOgogIGhlcm1lc19uZXQ6CiAgICBkcml2ZXI6IGJyaWRnZQo='))"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to write docker-compose.yml
    pause
    exit /b 1
)
echo [OK] docker-compose.yml written.

echo [2/4] Writing Dockerfile...
powershell -NoProfile -Command "[IO.File]::WriteAllBytes('Dockerfile', [Convert]::FromBase64String('IyAxLiBQdWxsIHRoZSBvZmZpY2lhbCwgcmVhZHktbWFkZSBwcmUtY29tcGlsZWQgaW1hZ2UgZGlyZWN0bHkKRlJPTSBub3VzcmVzZWFyY2gvaGVybWVzLWFnZW50OmxhdGVzdAoKIyAyLiBCcmllZmx5IHN3aXRjaCB0byByb290IHRvIGluc3RhbGwgc3lzdGVtLWxldmVsIHBhY2thZ2VzClVTRVIgcm9vdAoKIyAzLiBJbnN0YWxsaW5nIGdsb2JhbGx5IGxldHMgeW91IHJ1biAnc2tpbGxraXQnIGRpcmVjdGx5IGluc3RlYWQgb2YgcmVseWluZyBvbiBucHggZG93bmxvYWRzClJVTiBucG0gaW5zdGFsbCAtZyBza2lsbGtpdEAxLjI0LjAKCiMgWzIwMjYtMDUtMTVdCiMgSW5zdGFsbCBtc210cCBhbmQgQ0EgY2VydGlmaWNhdGVzIChuZWVkZWQgZm9yIFRMUy9HbWFpbCkKUlVOIGFwdC1nZXQgdXBkYXRlICYmIGFwdC1nZXQgaW5zdGFsbCAteSBcCiAgICBtc210cCBcCiAgICBtc210cC1tdGEgXAogICAgY2EtY2VydGlmaWNhdGVzIFwKICAgICYmIHJtIC1yZiAvdmFyL2xpYi9hcHQvbGlzdHMvKgo='))"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to write Dockerfile
    pause
    exit /b 1
)
echo [OK] Dockerfile written.

echo [3/4] Writing Dockerfile.camofox...
powershell -NoProfile -Command "[IO.File]::WriteAllBytes('Dockerfile.camofox', [Convert]::FromBase64String('RlJPTSBnaGNyLmlvL2pvLWluYy9jYW1vZm94LWJyb3dzZXI6MS4xMS4yCgojIEluc3RhbGwgVk5DICsgbm9WTkMgZGVwZW5kZW5jaWVzIChEZWJpYW4gQm9va3dvcm0gcGFja2FnZSBuYW1lcykKUlVOIGFwdC1nZXQgdXBkYXRlICYmIGFwdC1nZXQgaW5zdGFsbCAteSAtLW5vLWluc3RhbGwtcmVjb21tZW5kcyBcCiAgICB4MTF2bmMgXAogICAgcHl0aG9uMy13ZWJzb2NraWZ5IFwKICAgIG5vdm5jIFwKICAgICYmIHJtIC1yZiAvdmFyL2xpYi9hcHQvbGlzdHMvKgoKIyBGbGlwIHZuYyBwbHVnaW4gZnJvbSBkaXNhYmxlZCB0byBlbmFibGVkIGluIGNvbmZpZwojIChFTkFCTEVfVk5DIGVudiB2YXIgaXMgTk9UIGNoZWNrZWQgd2hlbiBwbHVnaW4gaXMgbGlzdGVkIHdpdGggZW5hYmxlZDpmYWxzZSkKUlVOIHNlZCAtaSAncy8idm5jIjogeyAiZW5hYmxlZCI6IGZhbHNlLyJ2bmMiOiB7ICJlbmFibGVkIjogdHJ1ZS8nIGNhbW9mb3guY29uZmlnLmpzb24KCiMgQmluZCBub1ZOQyB0byBhbGwgaW50ZXJmYWNlcyBzbyBEb2NrZXIgcG9ydCBtYXBwaW5nIHdvcmtzCkVOViBWTkNfQklORD0wLjAuMC4wCgpFWFBPU0UgNjA4MAo='))"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to write Dockerfile.camofox
    pause
    exit /b 1
)
echo [OK] Dockerfile.camofox written.

echo [4/4] Writing .dockerignore...
powershell -NoProfile -Command "[IO.File]::WriteAllBytes('.dockerignore', [Convert]::FromBase64String('Y2Ftb2ZveC1icm93c2VyLwpkaXN0LwouZ2l0LwoqLmJhdAo='))"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to write .dockerignore
    pause
    exit /b 1
)
echo [OK] .dockerignore written.




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
    echo   Camofox VNC: http://localhost:6080
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
