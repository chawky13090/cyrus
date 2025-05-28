#!/bin/bash

# Unified AI Agent - Start Script

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # Should be unified_agent directory
ECOSYSTEM_FILE="$AGENT_DIR/unified_agent_ecosystem.config.js"
ENV_FILE="$AGENT_DIR/backend/.env"
LOG_DIR="$AGENT_DIR/logs"

COLOR_INFO='[0;32m'
COLOR_WARN='[0;33m'
COLOR_ERROR='[0;31m'
COLOR_RESET='[0m'

log_info() { echo -e "${COLOR_INFO}[INFO] $1${COLOR_RESET}"; }
log_warn() { echo -e "${COLOR_WARN}[WARN] $1${COLOR_RESET}"; }
log_error() { echo -e "${COLOR_ERROR}[ERROR] $1${COLOR_RESET}"; }

# 1. Check if PM2 is installed
if ! command -v pm2 >/dev/null 2>&1; then
    log_error "PM2 is not installed or not in PATH. Please run the main installer or install PM2 globally ('sudo npm install -g pm2')."
    exit 1
fi

# 2. Check if ecosystem file exists
if [ ! -f "$ECOSYSTEM_FILE" ]; then
    log_error "PM2 ecosystem file not found: $ECOSYSTEM_FILE. Please ensure installation was complete."
    exit 1
fi

# 3. Check Ollama (basic check)
if command -v ollama >/dev/null 2>&1; then
    DEFAULT_OLLAMA_MODEL=$(grep OLLAMA_DEFAULT_MODEL "$ENV_FILE" 2>/dev/null | cut -d '=' -f2)
    if [ -z "$DEFAULT_OLLAMA_MODEL" ]; then DEFAULT_OLLAMA_MODEL="llama3"; fi # Fallback

    if ! ollama list | grep -q "$DEFAULT_OLLAMA_MODEL"; then
        log_warn "Ollama is running, but the default model '$DEFAULT_OLLAMA_MODEL' configured in .env might not be available."
        log_warn "You may need to run: ollama pull $DEFAULT_OLLAMA_MODEL"
    else
        log_info "Ollama is running and default model '$DEFAULT_OLLAMA_MODEL' appears to be available."
    fi
else
    log_warn "Ollama command not found. The agent's AI capabilities will be limited. Please install and run Ollama."
fi

# 4. Start the application using PM2
log_info "Starting Unified AI Agent backend using PM2 (ecosystem file: $ECOSYSTEM_FILE)..."
if pm2 start "$ECOSYSTEM_FILE"; then
    log_info "Unified AI Agent backend started/restarted successfully via PM2."
    pm2 save # Persist PM2 process list
    echo ""
    FLASK_APP_PORT=$(grep FLASK_RUN_PORT "$ENV_FILE" 2>/dev/null | cut -d '=' -f2)
    if [ -z "$FLASK_APP_PORT" ]; then FLASK_APP_PORT=5050; fi
    log_info "Backend API should be available at http://localhost:$FLASK_APP_PORT (if not proxied otherwise)."
    log_info "Check frontend access method (e.g., http://localhost:3000 if using 'npm start' in frontend, or your production setup)."
    log_info "View logs with: pm2 logs unified-agent-backend"
else
    log_error "Failed to start the agent with PM2. Check PM2 logs for details: pm2 logs"
fi

exit 0
```
