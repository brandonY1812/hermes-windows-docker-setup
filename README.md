# Hermes Agent — One-Click Windows Setup

[English](#hermes-agent--one-click-windows-setup) | [中文](#hermes-agent--windows-一鍵部署)

A Docker Compose stack that boots a full Hermes Agent environment on **Windows 11 x86-64** with one double-click. Three services: the Hermes gateway + dashboard, a headless browser (Camofox with VNC), and a privacy-respecting search engine (SearXNG). Download the whole repo and double-click the `.bat` — it's that simple.

> **Prerequisite:** [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/) must be installed and running before executing the script.

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  setup-hermes.bat  (double-click to run)    │
│  ├── Checks Docker is installed & running   │
│  ├── Creates data directories               │
│  ├── Generates default config.yaml + .env   │
│  ├── Verifies required files are present    │
│  ├── docker compose up -d --build           │
│  └── Patches SearXNG settings, restarts     │
└─────────────────────────────────────────────┘
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
     ┌─────────┐ ┌─────────┐ ┌──────────┐
     │ hermes  │ │ camofox │ │ searxng  │
     │ :9119   │ │ :9377   │ │  :8888   │
     │         │ │ :6080   │ │          │
     └─────────┘ └─────────┘ └──────────┘
        gateway     browser     search
       dashboard   (VNC web)   engine
```

| Service  | Port | Description |
|----------|------|-------------|
| Hermes   | 9119 | Gateway + web dashboard |
| Camofox  | 9377 | Headless browser API |
| Camofox  | 6080 | noVNC web desktop (view the browser) |
| SearXNG  | 8888 | Privacy metasearch engine |

---

## How to use

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) for Windows.
2. Start Docker Desktop and wait until it's ready.
3. Download the whole repository (all files, not just the `.bat`) — either `git clone` or download the ZIP from GitHub and extract it.
4. Double-click `setup-hermes.bat`.
5. After the build finishes, open http://localhost:9119 in your browser.
   - Login with username **admin** and password **admin** (you can change these in `docker-compose.yml`).
   - On the left sidebar, go to **Keys** and add your LLM API key.
   - Go to **Models** and select the model from your LLM provider.
   - Head to **Chat** — you're ready to go.
6. (Alternative) Edit `hermes_data\.hermes\.env` with your API key for programmatic access.

To stop: `docker compose down`  
To see logs: `docker compose logs -f hermes`  
To restart: `docker compose up -d`

---

## Changes made on top of the original images

None of the base images ship ready for this use case out of the box. Every customization below exists to solve a real problem that blocked the stack from working.

### Dockerfile — builds on `nousresearch/hermes-agent:v2026.6.19`

| Change | Reason |
|--------|--------|
| `npm install -g skillkit@1.24.0` | Hermes skills reference `skillkit` commands. Installing globally avoids per-invocation npx downloads (slow, network-dependent). |
| `apt-get install msmtp msmtp-mta ca-certificates` | The agent sends email notifications (e.g. cron job results) via Gmail SMTP. msmtp is the sendmail-compatible relay; ca-certificates provides TLS trust. |
| `rm -rf /var/lib/apt/lists/*` | Shrinks the image layer by cleaning apt package lists after install. |

### Dockerfile.camofox — builds on `ghcr.io/jo-inc/camofox-browser:1.11.2`

| Change | Reason |
|--------|--------|
| `apt-get install x11vnc python3-websockify novnc` | Adds remote desktop access to the headless browser so you can see what the agent is doing. No GUI on the Docker host, so VNC is the only way to inspect the browser visually. |
| `sed` to enable VNC plugin in `camofox.config.json` | VNC plugin is listed as `enabled: false` in the base image config. The `ENABLE_VNC` env var is **not checked** when the plugin is listed with `enabled: false` — it must be flipped to `true` in the JSON. |
| `ENV VNC_BIND=0.0.0.0` | Default VNC bind is `127.0.0.1` (localhost only). Docker port mapping requires binding to `0.0.0.0` (all interfaces) for external access. |
| `EXPOSE 6080` | noVNC web client port. |

### docker-compose.yml — pinned images for stability

| Change | Reason |
|--------|--------|
| Hermes image pinned to `v2026.6.19` | Uses a specific tag instead of `latest` to avoid breaking changes from future image updates. |
| SearXNG image pinned to `2026.6.29-28d388576` | Same reason — a specific, tested version avoids surprise breakage. |
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME/PASSWORD` | Secures the dashboard with basic auth (change the password in production). |
| `mem_limit: 4g` / `cpus: 2.0` | Caps resource usage so Docker doesn't starve the Windows host. |
| Volume: `.\hermes_data\.hermes:/opt/data` | Persists all configuration, skills, memories, and cron jobs on the Windows filesystem. Survives container rebuilds. |
| Volume: `.\hermes_data\downloads:/opt/downloads` | Shared download directory between hermes and camofox (browser downloads land here). |
| Volume: `.\hermes_data\.camofox-docker:/root/.camofox` | Persists camofox browser profiles and session data. |
| `depends_on` with `condition: service_started` | Hermes won't start until camofox and searxng are up, avoiding startup race conditions. |
| `command: ["gateway", "run"]` | Overrides the default entrypoint to start the gateway (not the TUI). |

### setup-hermes.bat

| Change | Reason |
|--------|--------|
| All config files shipped as real files | docker-compose.yml, Dockerfile, and Dockerfile.camofox are regular files in the repo — no base64 decoding at runtime. Just download and double-click. |
| File verification on startup | Checks that the three required files (docker-compose.yml, Dockerfile, Dockerfile.camofox) exist before building. Fails fast with a clear message if anything is missing. |
| Auto-generates `config.yaml` | Prevents the first-time setup wizard from crashing inside Docker. Sets approvals mode to `smart` so commands are auto-approved based on heuristics instead of prompting. Configures camofox as the browser cloud provider with managed persistence, visible-tab session handling, and appropriate timeouts — all tuned so the headless browser works out of the box. |
| Auto-generates `.env` with `CAMOFOX_URL` and `SEARXNG_URL` | Sets the internal Docker network URLs so Hermes can reach the other services by container name. |
| Post-start SearXNG settings patch | The default SearXNG `settings.yml` only outputs HTML. Hermes needs the `json` format to parse search results. The script pulls the config, appends the format, pushes it back, and restarts. |

---

## File overview

```
.
├── setup-hermes.bat       ← Double-click this (one-click bootstrap)
├── docker-compose.yml     ← Docker Compose service definitions
├── Dockerfile             ← Hermes Agent image customizations
├── Dockerfile.camofox     ← Camofox + noVNC image customizations
├── .dockerignore          ← Files excluded from Docker build context
├── index.html             ← noVNC landing page (auto-reconnect)
├── patch-novnc.py         ← Patches noVNC for auto-reconnect
├── vnc-watcher.sh         ← VNC connection watcher script
├── hermes_data/           ← Created at runtime (persistent data)
│   └── .hermes/
│       ├── config.yaml
│       └── .env
├── searxng/               ← Created at runtime (SearXNG config)
└── README.md
```

---

# Hermes Agent — Windows 一鍵部署

[English](#hermes-agent--one-click-windows-setup) | [中文](#hermes-agent--windows-一鍵部署)

一個 Docker Compose 環境，在 **Windows 11 x86-64** 上點兩下就能啟動完整的 Hermes Agent 系統。包含三個服務：Hermes 閘道器 + 儀表板、無頭瀏覽器（Camofox + VNC 遠端桌面），以及尊重隱私的搜尋引擎（SearXNG）。下載整個 repo，點兩下 `.bat` 即可執行。

> **前置需求：** 執行腳本前，必須先安裝並啟動 [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)。

---

## 架構

```
┌─────────────────────────────────────────────┐
│  setup-hermes.bat  （點兩下執行）            │
│  ├── 檢查 Docker 是否已安裝並執行中          │
│  ├── 建立資料目錄                            │
│  ├── 產生預設 config.yaml + .env            │
│  ├── 驗證必要檔案存在                        │
│  ├── docker compose up -d --build           │
│  └── 修補 SearXNG 設定後重啟                 │
└─────────────────────────────────────────────┘
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
     ┌─────────┐ ┌─────────┐ ┌──────────┐
     │ hermes  │ │ camofox │ │ searxng  │
     │ :9119   │ │ :9377   │ │  :8888   │
     │         │ │ :6080   │ │          │
     └─────────┘ └─────────┘ └──────────┘
       閘道器      瀏覽器      搜尋引擎
       儀表板     (VNC 網頁)
```

| 服務     | 埠號 | 說明 |
|----------|------|------|
| Hermes   | 9119 | 閘道器 + 網頁儀表板 |
| Camofox  | 9377 | 無頭瀏覽器 API |
| Camofox  | 6080 | noVNC 網頁遠端桌面（查看瀏覽器畫面） |
| SearXNG  | 8888 | 隱私保護的元搜尋引擎 |

---

## 使用方法

1. 安裝 [Docker Desktop](https://www.docker.com/products/docker-desktop/) for Windows。
2. 啟動 Docker Desktop，等待它就緒。
3. 從 GitHub 下載整個 repository（所有檔案，不只是 `.bat`）— 可以用 `git clone` 或下載 ZIP 後解壓縮。
4. 點兩下 `setup-hermes.bat`。
5. 建置完成後，在瀏覽器中開啟 http://localhost:9119。
   - 使用使用者名稱 **admin** 和密碼 **admin** 登入（可以在 `docker-compose.yml` 中修改）。
   - 在左側選單中，前往 **Keys** 並新增你的 LLM API 金鑰。
   - 前往 **Models**，從你的 LLM 供應商中選擇模型。
   - 前往 **Chat** — 就可以開始使用了。
6. （替代方式）編輯 `hermes_data\.hermes\.env` 以寫入 API 金鑰，供程式化存取使用。

停止：`docker compose down`  
查看日誌：`docker compose logs -f hermes`  
重新啟動：`docker compose up -d`

---

## 在原始映像檔之上的客製化變更

基礎映像檔都不會針對這個使用情境預先設定好。以下每一項客製化都是為了解決一個實際會阻礙系統運作的問題。

### Dockerfile — 基於 `nousresearch/hermes-agent:v2026.6.19` 構建

| 變更 | 原因 |
|--------|--------|
| `npm install -g skillkit@1.24.0` | Hermes 的技能（skills）會呼叫 `skillkit` 指令。全域安裝可避免每次呼叫時透過 npx 下載（速度慢且依賴網路）。 |
| `apt-get install msmtp msmtp-mta ca-certificates` | Agent 需要透過 Gmail SMTP 發送郵件通知（例如 cron 排程的執行結果）。msmtp 是相容 sendmail 的郵件轉發工具；ca-certificates 提供 TLS 信任鏈。 |
| `rm -rf /var/lib/apt/lists/*` | 安裝後清除 apt 套件清單，縮小映像層大小。 |

### Dockerfile.camofox — 基於 `ghcr.io/jo-inc/camofox-browser:1.11.2` 構建

| 變更 | 原因 |
|--------|--------|
| `apt-get install x11vnc python3-websockify novnc` | 為無頭瀏覽器加入遠端桌面功能，讓你可以看到 Agent 正在瀏覽什麼。Docker 主機沒有 GUI，VNC 是唯一能視覺化檢查瀏覽器的方法。 |
| `sed` 啟用 `camofox.config.json` 中的 VNC 外掛 | VNC 外掛在基礎映像的設定中被列為 `enabled: false`。`ENABLE_VNC` 環境變數在外掛被標記為 `enabled: false` 時**不會被檢查** — 必須先在 JSON 設定中改為 `true`。 |
| `ENV VNC_BIND=0.0.0.0` | 預設 VNC 綁定位址是 `127.0.0.1`（僅本機）。Docker 埠號對應需要綁定到 `0.0.0.0`（所有網路介面）才能從外部存取。 |
| `EXPOSE 6080` | noVNC 網頁客戶端埠號。 |

### docker-compose.yml — 固定映像版本以確保穩定性

| 變更 | 原因 |
|--------|--------|
| Hermes 映像固定為 `v2026.6.19` | 使用特定標籤而非 `latest`，避免未來映像更新造成相容性問題。 |
| SearXNG 映像固定為 `2026.6.29-28d388576` | 同樣原因 — 使用經測試的特定版本，避免意外故障。 |
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME/PASSWORD` | 以基本驗證保護儀表板（請在正式環境中修改密碼）。 |
| `mem_limit: 4g` / `cpus: 2.0` | 限制資源用量，避免 Docker 佔滿 Windows 主機的資源。 |
| 磁碟區：`.\hermes_data\.hermes:/opt/data` | 將所有設定、技能、記憶與排程保存在 Windows 檔案系統上。重建容器後資料不會遺失。 |
| 磁碟區：`.\hermes_data\downloads:/opt/downloads` | hermes 與 camofox 共用的下載目錄（瀏覽器下載的檔案會存在這裡）。 |
| 磁碟區：`.\hermes_data\.camofox-docker:/root/.camofox` | 保存 camofox 瀏覽器的設定檔與工作階段資料。 |
| `depends_on` 搭配 `condition: service_started` | Hermes 會等到 camofox 和 searxng 都啟動後才開始，避免啟動競爭條件。 |
| `command: ["gateway", "run"]` | 覆蓋預設進入點，改為啟動閘道器（而非 TUI）。 |

### setup-hermes.bat

| 變更 | 原因 |
|--------|--------|
| 所有設定檔以真實檔案提供 | docker-compose.yml、Dockerfile、Dockerfile.camofox 都是 repo 中的一般檔案 — 不需要在執行時解碼 base64。下載後直接點兩下即可。 |
| 啟動時驗證必要檔案 | 檢查三個必要檔案（docker-compose.yml、Dockerfile、Dockerfile.camofox）是否存在。如果遺失會快速失敗並顯示清楚的錯誤訊息。 |
| 自動產生 `config.yaml` | 防止首次啟動設定精靈在 Docker 中崩潰。將 approvals 模式設為 `smart`，讓指令根據啟發式規則自動核准，免去手動確認。同時將 camofox 設為瀏覽器雲端供應商，配置 managed persistence、visible-tab 工作階段處理及適當的逾時設定 — 讓無頭瀏覽器開箱即用。 |
| 自動產生 `.env`，包含 `CAMOFOX_URL` 和 `SEARXNG_URL` | 設定 Docker 內部網路 URL，讓 Hermes 能透過容器名稱找到其他服務。 |
| 啟動後修補 SearXNG 設定 | 預設的 SearXNG `settings.yml` 只輸出 HTML。Hermes 需要 `json` 格式才能解析搜尋結果。腳本會拉出設定檔、附加格式設定、推回容器，然後重啟。 |

---

## 檔案總覽

```
.
├── setup-hermes.bat       ← 點兩下這個（一鍵啟動腳本）
├── docker-compose.yml     ← Docker Compose 服務定義
├── Dockerfile             ← Hermes Agent 映像客製化
├── Dockerfile.camofox     ← Camofox + noVNC 映像客製化
├── .dockerignore          ← Docker 建置時排除的檔案
├── index.html             ← noVNC 登陸頁面（自動重連）
├── patch-novnc.py         ← 修補 noVNC 以支援自動重連
├── vnc-watcher.sh         ← VNC 連線監控腳本
├── hermes_data/           ← 執行時產生（持久化資料）
│   └── .hermes/
│       ├── config.yaml
│       └── .env
├── searxng/               ← 執行時產生（SearXNG 設定）
└── README.md
```
