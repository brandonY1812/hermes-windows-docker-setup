# =============================================================================
# Hermes Agent Dockerfile
# =============================================================================
# Starts from the official pre-built Hermes image, then adds extra system
# packages that the agent needs at runtime (skillkit, msmtp for email).
# =============================================================================

# 1. Pull the official, ready-made pre-compiled image directly
FROM nousresearch/hermes-agent:v2026.6.19

# 2. Briefly switch to root to install system-level packages
USER root

# 3. skillkit — installed globally so `skillkit` runs directly (no npx download)
RUN npm install -g skillkit@1.24.0

# 4. msmtp + CA certificates — needed to send email via TLS (Gmail, etc.)
#    Added 2026-05-15
RUN apt-get update && apt-get install -y \
    msmtp \
    msmtp-mta \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
