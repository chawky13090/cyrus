#!/bin/bash
# Unified AI Agent Installer - MVP
# This script installs the Unified AI Agent, including backend, frontend, and dependencies.

# --- Configuration ---
PROJECT_DIR_NAME="unified_agent"
INSTALL_DIR="\$HOME/\$PROJECT_DIR_NAME" # Corrected
PYTHON_CMD="python3"
NODE_CMD="node" # Will check for nodejs too
NPM_CMD="npm"
MIN_PYTHON_MAJOR=3
MIN_PYTHON_MINOR=8 # Example: require Python 3.8+
MIN_NODE_MAJOR=16 # Example: require Node.js 16+

# --- Colors for Logging ---
# These are fine as they are literal strings assigned to vars
COLOR_RESET='[0m'
COLOR_INFO='[0;32m'
COLOR_WARN='[0;33m'
COLOR_ERROR='[0;31m'
COLOR_STEP='[1;34m'

# --- Logging Functions ---
# $1 is a parameter to the shell function, so \$1 ensures it's literal $1 in the script
log_info() { echo -e "\${COLOR_INFO}[INFO] \$(date +'%T') - \$1\${COLOR_RESET}"; }
log_warn() { echo -e "\${COLOR_WARN}[WARN] \$(date +'%T') - \$1\${COLOR_RESET}"; }
log_error() { echo -e "\${COLOR_ERROR}[ERROR] \$(date +'%T') - \$1\${COLOR_RESET}"; }
log_step() { echo -e "
\${COLOR_STEP}>>> \$1\${COLOR_RESET}"; }

# --- Helper Functions ---
check_command() {
    command -v "\$1" >/dev/null 2>&1 # Corrected \$1
}

check_not_root() {
    if [ "\$(id -u)" -eq 0 ]; then # Corrected \$()
        log_error "This script should not be run as root. Please run as a regular user with sudo privileges for system installations."
        exit 1
    fi
}

version_check() {
    if [ "\$(printf '%s\n' "\$2" "\$1" | sort -V | head -n1)" = "\$2" ]; then # Corrected \$(), \$1, \$2
        return 0
    else
        return 1
    fi
}

# --- Main Installation Logic ---
main() {
    check_not_root
    log_step "Starting Unified AI Agent MVP Installation"
    log_info "This script will install system dependencies, Python backend, Node.js frontend, and configure the agent."
    log_info "Installation directory: \${INSTALL_DIR}" # Corrected \${INSTALL_DIR} (or \$INSTALL_DIR)
    echo ""
    read -p "Proceed with installation? (y/N): " confirm_install
    if [[ "\$confirm_install" != [yY] && "\$confirm_install" != [yY][eE][sS] ]]; then # Corrected \$confirm_install
        log_info "Installation aborted by user."
        exit 0
    fi

    CURRENT_SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    if [ "\$(basename "\$CURRENT_SCRIPT_DIR")" != "\$PROJECT_DIR_NAME" ]; then # Corrected
        log_warn "Installer script is expected to be inside the '\$PROJECT_DIR_NAME' directory." # Corrected
    fi
    INSTALL_DIR="\$CURRENT_SCRIPT_DIR" # Corrected
    cd "\$INSTALL_DIR"  # Corrected
    log_info "Using installation directory: \$INSTALL_DIR" # Corrected

    log_step "[1/7] Installing System Dependencies (sudo required)..."
    REQUIRED_SYS_DEPS=("curl" "git" "\$PYTHON_CMD" "python3-venv" "python3-pip" "\$NODE_CMD" "\$NPM_CMD" "nmap" "pm2") # Corrected
    MISSING_SYS_DEPS=()

    for dep in "\${REQUIRED_SYS_DEPS[@]}"; do # Corrected
        if ! check_command "\$dep"; then # Corrected
            if [[ "\$dep" == "\$NODE_CMD" ]] && check_command "nodejs"; then # Corrected
                log_info "'\$NODE_CMD' not found, but 'nodejs' is. Using 'nodejs'." # Corrected
                NODE_CMD="nodejs" 
            elif [[ "\$dep" == "\$NODE_CMD" ]] && ! check_command "nodejs"; then # Corrected
                 MISSING_SYS_DEPS+=("nodejs") 
            elif [[ "\$dep" == "pm2" ]]; then 
                continue
            else
                MISSING_SYS_DEPS+=("\$dep") # Corrected
            fi
        fi
    done
    
    if ! check_command "pm2"; then
        log_info "PM2 not found. Will attempt to install globally via npm."
    fi

    if [ \${#MISSING_SYS_DEPS[@]} -ne 0 ]; then # Corrected
        log_info "Missing system dependencies: \${MISSING_SYS_DEPS[*]}" # Corrected
        log_info "Attempting installation using apt..."
        sudo apt-get update -y || log_warn "apt-get update failed. Trying to continue..."
        APT_DEPS=()
        for dep in "\${MISSING_SYS_DEPS[@]}"; do # Corrected
            if [[ "\$dep" != "npm" && "\$dep" != "python3-pip" && "\$dep" != "pm2" ]]; then # Corrected
                if [[ "\$dep" == "python3-venv" ]]; then # Corrected
                    APT_DEPS+=("python3.\$(echo \$MIN_PYTHON_MINOR)-venv" "python3-venv") # Corrected \$(echo...)
                else
                    APT_DEPS+=("\$dep") # Corrected
                fi
            fi
        done
        if [ \${#APT_DEPS[@]} -ne 0 ]; then # Corrected
            sudo apt-get install -y --no-install-recommends \${APT_DEPS[*]} || { # Corrected
                log_error "Failed to install some system dependencies: \${APT_DEPS[*]}. Please install them manually and restart." # Corrected
                exit 1
            }
        fi
        log_info "System dependencies installation attempt complete."
    else
        log_info "Core system dependencies seem to be present."
    fi
    
    if check_command "\$PYTHON_CMD"; then # Corrected
        CURRENT_PYTHON_VERSION=\$("\$PYTHON_CMD" -c 'import sys; sys.stdout.write(str(sys.version_info.major) + "." + str(sys.version_info.minor))') # Corrected as per user
        log_info "Python version: \$CURRENT_PYTHON_VERSION" # Corrected
        if ! version_check "\$CURRENT_PYTHON_VERSION" "\$MIN_PYTHON_MAJOR.\$MIN_PYTHON_MINOR"; then # Corrected
            log_error "Python version \$MIN_PYTHON_MAJOR.\$MIN_PYTHON_MINOR or higher is required. Found \$CURRENT_PYTHON_VERSION." # Corrected
            exit 1
        fi
    else
        log_error "\$PYTHON_CMD is not installed. Please install Python \$MIN_PYTHON_MAJOR.\$MIN_PYTHON_MINOR+." # Corrected
        exit 1
    fi

    if check_command "\$NODE_CMD"; then # Corrected
        CURRENT_NODE_VERSION=\$("\$NODE_CMD" -v | sed 's/v//') # Corrected
        log_info "Node.js version: \$CURRENT_NODE_VERSION" # Corrected
        if ! version_check "\$CURRENT_NODE_VERSION" "\$MIN_NODE_MAJOR.0"; then # Corrected
            log_error "Node.js version \$MIN_NODE_MAJOR or higher is required. Found \$CURRENT_NODE_VERSION." # Corrected
            exit 1
        fi
    else
        log_error "\$NODE_CMD (or nodejs) is not installed. Please install Node.js \$MIN_NODE_MAJOR+." # Corrected
        exit 1
    fi
    
    if ! check_command "pm2"; then
        log_step "[2/7] Installing/Updating PM2 globally via npm (sudo required)..."
        if sudo "\$NPM_CMD" install -g pm2; then # Corrected
            log_info "PM2 installed successfully globally."
        else
            log_error "Failed to install PM2 globally. Please try manually: 'sudo npm install -g pm2'"
            exit 1
        fi
    else
        log_info "PM2 is already installed."
    fi

    log_step "[3/7] Setting up Python Backend in ./backend/ ..."
    cd "\$INSTALL_DIR/backend" || { log_error "Backend directory not found!"; exit 1; } # Corrected

    if [ ! -f "requirements.txt" ]; then
        log_error "requirements.txt not found in backend directory!"
        exit 1
    fi
    
    if [ ! -d "venv" ]; then
        log_info "Creating Python virtual environment..."
        "\$PYTHON_CMD" -m venv venv || { log_error "Failed to create venv."; exit 1; } # Corrected
    fi
    
    log_info "Activating Python virtual environment..."
    source "./venv/bin/activate" || { log_error "Failed to activate venv."; exit 1; }
    
    log_info "Installing Python dependencies from requirements.txt..."
    pip install --upgrade pip
    pip install -r requirements.txt || { 
        log_error "Failed to install Python dependencies."
        deactivate
        exit 1
    }
    log_info "Python dependencies installed."
    deactivate 
    cd "\$INSTALL_DIR" # Corrected

    log_step "[4/7] Setting up Node.js Frontend in ./frontend/ ..."
    cd "\$INSTALL_DIR/frontend" || { log_error "Frontend directory not found!"; exit 1; } # Corrected

    if [ ! -f "package.json" ]; then
        log_error "package.json not found in frontend directory!"
        exit 1
    fi

    log_info "Installing Node.js dependencies from package.json..."
    "\$NPM_CMD" install || {  # Corrected
        log_error "Failed to install Node.js dependencies."
        exit 1
    }
    log_info "Node.js dependencies installed."

    log_info "Building React frontend (this may take a few minutes)..."
    "\$NPM_CMD" run build || { # Corrected
        log_error "React build failed. Please check errors above."
        exit 1
    }
    log_info "React frontend built successfully."
    cd "\$INSTALL_DIR" # Corrected

    log_step "[5/7] Checking Ollama Installation..."
    DEFAULT_OLLAMA_MODEL=\$(grep OLLAMA_DEFAULT_MODEL "\$INSTALL_DIR/backend/.env.example" 2>/dev/null | cut -d '=' -f2) # Corrected
    if [ -z "\$DEFAULT_OLLAMA_MODEL" ]; then DEFAULT_OLLAMA_MODEL="llama3"; fi # Corrected

    if check_command "ollama"; then
        log_info "Ollama is installed."
        if ! ollama list | grep -q "\$DEFAULT_OLLAMA_MODEL"; then # Corrected
            log_warn "Default Ollama model '\$DEFAULT_OLLAMA_MODEL' not found locally." # Corrected
            read -p "Attempt to pull '\$DEFAULT_OLLAMA_MODEL' now? (y/N): " confirm_pull # Corrected
            if [[ "\$confirm_pull" == [yY] || "\$confirm_pull" == [yY][eE][sS] ]]; then # Corrected
                log_info "Pulling '\$DEFAULT_OLLAMA_MODEL'... this may take some time." # Corrected
                if ollama pull "\$DEFAULT_OLLAMA_MODEL"; then # Corrected
                    log_info "'\$DEFAULT_OLLAMA_MODEL' pulled successfully." # Corrected
                else
                    log_error "Failed to pull '\$DEFAULT_OLLAMA_MODEL'. Please try manually." # Corrected
                fi
            else
                log_warn "Skipping model pull. Please ensure '\$DEFAULT_OLLAMA_MODEL' or your configured model is available in Ollama." # Corrected
            fi
        else
            log_info "Default Ollama model '\$DEFAULT_OLLAMA_MODEL' is available." # Corrected
        fi
        if ! ollama list > /dev/null 2>&1; then 
             log_warn "Ollama is installed but not responding. Please start Ollama manually: 'ollama serve'"
        else
            log_info "Ollama is running and responding."
        fi
    else
        log_warn "Ollama is not installed. Please install from https://ollama.com/ and ensure a model is downloaded."
    fi

    log_step "[6/7] Setting up Configuration (.env file)..."
    cd "\$INSTALL_DIR/backend" || { log_error "Backend directory not found!"; exit 1; } # Corrected
    if [ -f ".env.example" ]; then
        if [ -f ".env" ]; then
            log_info ".env file already exists. Skipping creation from .env.example."
            log_warn "Please ensure your existing .env file in ./backend/ has all necessary variables."
        else
            cp .env.example .env
            NEW_SECRET_KEY=\$(openssl rand -hex 32) # Corrected
            sed -i "s|your_very_secret_flask_key_here|\$NEW_SECRET_KEY|" .env # Corrected
            
            NEW_BASIC_AUTH_PASSWORD=\$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16) # Corrected
            sed -i "s/^BASIC_AUTH_PASSWORD=.*/BASIC_AUTH_PASSWORD=\$NEW_BASIC_AUTH_PASSWORD/" .env # Corrected
            log_info "A new random password for Basic Authentication has been generated."
            log_info "Created .env file from .env.example in ./backend/."
            log_warn "IMPORTANT: Review './backend/.env'. Generated SECRET_KEY and BASIC_AUTH_PASSWORD are set."
        fi
    else
        log_error ".env.example not found in backend. Cannot create .env configuration."
        exit 1
    fi
    cd "\$INSTALL_DIR" # Corrected

    log_step "[7/7] Setting up PM2 for the Backend..."
    ECOSYSTEM_FILE="\$INSTALL_DIR/unified_agent_ecosystem.config.js" # Corrected
    FLASK_APP_PORT=\$(grep FLASK_RUN_PORT "\$INSTALL_DIR/backend/.env" | cut -d '=' -f2) # Corrected
    if [ -z "\$FLASK_APP_PORT" ]; then FLASK_APP_PORT=5050; fi # Corrected

    log_info "Creating PM2 ecosystem file: \$ECOSYSTEM_FILE" # Corrected
    # Note: Inside this heredoc, variables like \${FLASK_APP_PORT} and \${INSTALL_DIR}
    # are meant to be expanded by the *installer.sh script itself* when it *writes* the ecosystem file.
    # So, they should be \$FLASK_APP_PORT and \$INSTALL_DIR (or \${FLASK_APP_PORT}, \${INSTALL_DIR})
    # to allow expansion by the shell executing the cat command.
    # The worker received this heredoc with \${INSTALL_DIR} etc. from me previously, which is correct for this part.
    # The user's error was not in this particular heredoc's variable expansion, but in general shell variable usage.
    # So, the content of this heredoc for ecosystem.config.js remains as previously defined by the worker.
    cat << EOF > "\$ECOSYSTEM_FILE" 
module.exports = {
  apps : [{
    name   : "unified-agent-backend",
    script : "\$INSTALL_DIR/backend/venv/bin/gunicorn",
    args   : ["-w", "4", "-k", "gevent", "--bind", "0.0.0.0:\${FLASK_APP_PORT}", "main:app"],
    cwd    : "\$INSTALL_DIR/backend/",
    interpreter: "\$INSTALL_DIR/backend/venv/bin/python",
    exec_mode : "cluster",
    instances : 1,
    autorestart: true,
    watch    : false,
    max_memory_restart: '1G',
    env: {
      // FLASK_ENV: "production", // .env should handle this
    },
    out_file: "\$INSTALL_DIR/logs/pm2-backend-out.log",
    error_file: "\$INSTALL_DIR/logs/pm2-backend-err.log",
    log_date_format: "YYYY-MM-DD HH:mm:ss Z"
  }]
};
EOF

    log_info "PM2 ecosystem file created."
    log_info "Attempting to start the Unified AI Agent backend via PM2..."
    if pm2 start "\$ECOSYSTEM_FILE"; then # Corrected
        log_info "Backend successfully started with PM2."
        pm2 save 
    else
        log_error "Failed to start backend with PM2. Please try starting it manually: pm2 start \$ECOSYSTEM_FILE" # Corrected
    fi
    
    chmod +x "\$INSTALL_DIR/start_agent.sh" "\$INSTALL_DIR/stop_agent.sh" # Corrected

    log_step "Installation Complete!"
    echo ""
    GENERATED_USERNAME=\$(grep BASIC_AUTH_USERNAME "\$INSTALL_DIR/backend/.env" | cut -d '=' -f2) # Corrected
    GENERATED_PASSWORD=\$(grep BASIC_AUTH_PASSWORD "\$INSTALL_DIR/backend/.env" | cut -d '=' -f2) # Corrected
    FLASK_PORT_FINAL=\$(grep FLASK_RUN_PORT "\$INSTALL_DIR/backend/.env" | cut -d '=' -f2) # Corrected
    if [ -z "\$FLASK_PORT_FINAL" ]; then FLASK_PORT_FINAL=5050; fi # Corrected

    log_info "--------------------------------------------------------------------"
    log_info "Unified AI Agent MVP installation finished."
    log_info "--------------------------------------------------------------------"
    echo ""
    log_info "IMPORTANT - Credentials for Web UI:"
    log_info "Username: \${COLOR_WARN}\$GENERATED_USERNAME\${COLOR_RESET}" # Corrected
    log_info "Password: \${COLOR_WARN}\$GENERATED_PASSWORD\${COLOR_RESET}" # Corrected
    log_info "Please save this password securely. You can change credentials in \$INSTALL_DIR/backend/.env" # Corrected
    log_info "--------------------------------------------------------------------"
    echo ""
    log_info "NEXT STEPS:"
    echo ""
    log_info "1. Ensure Ollama is Running & Model Downloaded:"
    log_info "   - Start Ollama if not already running: \${COLOR_WARN}ollama serve\${COLOR_RESET}"
    log_info "   - Ensure the default model is pulled: \${COLOR_WARN}ollama pull \$(grep OLLAMA_DEFAULT_MODEL "\$INSTALL_DIR/backend/.env" | cut -d '=' -f2)\${COLOR_RESET}" # Corrected
    echo ""
    log_info "2. Manage the Application:"
    log_info "   Start: \${COLOR_WARN}\$INSTALL_DIR/start_agent.sh\${COLOR_RESET}" # Corrected
    log_info "   Stop:  \${COLOR_WARN}\$INSTALL_DIR/stop_agent.sh\${COLOR_RESET}" # Corrected
    echo ""
    log_info "3. Access the Web Interface:"
    log_info "   The backend API runs at: \${COLOR_WARN}http://localhost:\$FLASK_PORT_FINAL\${COLOR_RESET}" # Corrected
    log_info "   For development (after 'cd unified_agent/frontend && npm start'), UI is at http://localhost:3000."
    log_info "   For production, serve static files from 'unified_agent/frontend/build/' via Nginx or similar, proxying '/api' to http://localhost:\$FLASK_PORT_FINAL." # Corrected
    echo ""
    log_info "View logs with: \${COLOR_WARN}pm2 logs unified-agent-backend\${COLOR_RESET} or check files in \${COLOR_WARN}\$INSTALL_DIR/logs/\${COLOR_RESET}" # Corrected
    echo ""
    log_info "--------------------------------------------------------------------"
}

main "\$@" # Corrected

exit 0
```
