#!/bin/bash

# Unified AI Agent - Stop Script

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Should be unified_agent directory
APP_NAME="unified-agent-backend" # Name from ecosystem file

COLOR_INFO='[0;32m'
COLOR_WARN='[0;33m'
COLOR_ERROR='[0;31m'
COLOR_RESET='[0m'

log_info() { echo -e "${COLOR_INFO}[INFO] $1${COLOR_RESET}"; }
log_warn() { echo -e "${COLOR_WARN}[WARN] $1${COLOR_RESET}"; }
log_error() { echo -e "${COLOR_ERROR}[ERROR] $1${COLOR_RESET}"; }


# 1. Check if PM2 is installed
if ! command -v pm2 >/dev/null 2>&1; then
    log_error "PM2 is not installed or not in PATH. Cannot stop agent managed by PM2."
    exit 1
fi

log_info "Stopping Unified AI Agent backend ('$APP_NAME') via PM2..."
if pm2 stop "$APP_NAME"; then
    log_info "'$APP_NAME' stopped successfully."
    log_info "Deleting '$APP_NAME' from PM2 process list..."
    if pm2 delete "$APP_NAME"; then
        log_info "'$APP_NAME' deleted successfully."
    else
        log_warn "Could not delete '$APP_NAME' from PM2 list. It might have already been deleted or never started."
    fi
    pm2 save # Persist changes
    log_info "PM2 process list saved."
else
    log_warn "Could not stop '$APP_NAME' via PM2. It might not be running or may not exist."
    log_warn "You can check current PM2 processes with 'pm2 list'."
fi

log_info "Unified AI Agent backend stop sequence complete."
exit 0
```
