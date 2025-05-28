#!/bin/bash

# Unified AI Agent Installer - MVP
# This script installs the Unified AI Agent, including backend, frontend, and dependencies.

# --- Configuration ---
PROJECT_DIR_NAME="unified_agent"
INSTALL_DIR="$HOME/$PROJECT_DIR_NAME"
PYTHON_CMD="python3"
NODE_CMD="node" # Will check for nodejs too
NPM_CMD="npm"
MIN_PYTHON_MAJOR=3
MIN_PYTHON_MINOR=8 # Example: require Python 3.8+
MIN_NODE_MAJOR=16 # Example: require Node.js 16+

# --- Colors for Logging ---
COLOR_RESET='[0m'
COLOR_INFO='[0;32m'    # Green
COLOR_WARN='[0;33m'    # Yellow
COLOR_ERROR='[0;31m'   # Red
COLOR_STEP='[1;34m'    # Bold Blue

# --- Logging Functions ---
log_info() { echo -e "${COLOR_INFO}[INFO] $(date +'%T') - $1${COLOR_RESET}"; }
log_warn() { echo -e "${COLOR_WARN}[WARN] $(date +'%T') - $1${COLOR_RESET}"; }
log_error() { echo -e "${COLOR_ERROR}[ERROR] $(date +'%T') - $1${COLOR_RESET}"; }
log_step() { echo -e "
${COLOR_STEP}>>> $1${COLOR_RESET}"; }

# --- Helper Functions ---
check_command() {
    command -v "$1" >/dev/null 2>&1
}

check_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        log_error "This script should not be run as root. Please run as a regular user with sudo privileges for system installations."
        exit 1
    fi
}

# Function to check version: version_check "16.0.0" "14.0.0"
version_check() {
    # $1 = current version, $2 = minimum version
    if [ "$(printf '%s
' "$2" "$1" | sort -V | head -n1)" = "$2" ]; then
        return 0 # current is >= minimum
    else
        return 1 # current is < minimum
    fi
}

# --- Main Installation Logic ---
main() {
    check_not_root
    log_step "Starting Unified AI Agent MVP Installation"
    log_info "This script will install system dependencies, Python backend, Node.js frontend, and configure the agent."
    log_info "Installation directory: ${INSTALL_DIR}"
    echo ""
    read -p "Proceed with installation? (y/N): " confirm_install
    if [[ "$confirm_install" != [yY] && "$confirm_install" != [yY][eE][sS] ]]; then
        log_info "Installation aborted by user."
        exit 0
    fi

    # 0. Ensure script is run from where it's located (or adjust paths)
    # For simplicity, assuming it's run from within the 'unified_agent' cloned directory.
    # If not, this needs to be more robust: SCRIPT_DIR="$( cd "$( dirname "\${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    # cd "\$SCRIPT_DIR" 
    # For now, we assume the installer.sh is in the root of the project files that are being installed.
    # So, if the user downloaded a zip and ran it, backend/frontend folders are relative to it.

    # 1. Create Installation Directory (if this script is outside the project dir)
    # If script is INSIDE project dir (e.g. unified_agent/installer.sh), then INSTALL_DIR is its parent.
    # This script assumes it's run from unified_agent/installer.sh and installs into unified_agent/
    # If it's a global installer, it would be:
    # mkdir -p "${INSTALL_DIR}"
    # cp -r ./* "${INSTALL_DIR}/" # if script is run from a source dir
    # cd "${INSTALL_DIR}"
    # For this MVP, we assume user has the 'unified_agent' folder (with backend, frontend, installer.sh)
    # and runs installer.sh from within 'unified_agent/'.
    # So, INSTALL_DIR will be the current directory.
    
    # Let's adjust INSTALL_DIR to be the directory containing this script.
    CURRENT_SCRIPT_DIR="$( cd "$( dirname "\${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    if [ "\$(basename "\$CURRENT_SCRIPT_DIR")" != "$PROJECT_DIR_NAME" ]; then
        log_warn "Installer script is expected to be inside the '$PROJECT_DIR_NAME' directory."
        # Optionally, allow user to specify or try to find it. For MVP, keep it simple.
        # For now, assume INSTALL_DIR is the directory of the script.
        # This means backend/ and frontend/ are siblings to installer.sh
    fi
    INSTALL_DIR="\$CURRENT_SCRIPT_DIR" # This is the root of the unified_agent project
    cd "\$INSTALL_DIR" 
    log_info "Using installation directory: \$INSTALL_DIR"


    # 2. Install System Dependencies
    log_step "[1/7] Installing System Dependencies (sudo required)..."
    # Added nmap, pm2
    REQUIRED_SYS_DEPS=("curl" "git" "$PYTHON_CMD" "python3-venv" "python3-pip" "$NODE_CMD" "$NPM_CMD" "nmap" "pm2") 
    MISSING_SYS_DEPS=()

    for dep in "\${REQUIRED_SYS_DEPS[@]}"; do
        if ! check_command "\$dep"; then
            # Special handling for nodejs vs node
            if [[ "\$dep" == "$NODE_CMD" ]] && check_command "nodejs"; then
                log_info "'$NODE_CMD' not found, but 'nodejs' is. Using 'nodejs'."
                NODE_CMD="nodejs" 
                # No need to add to missing if nodejs exists
                elif [[ "\$dep" == "$NODE_CMD" ]] && ! check_command "nodejs"; then
                 MISSING_SYS_DEPS+=("nodejs") # Prefer nodejs if node is missing
            elif [[ "\$dep" == "pm2" ]]; then # pm2 is installed via npm later
                continue
            else
                MISSING_SYS_DEPS+=("\$dep")
            fi
        fi
    done
    
    # Install PM2 via NPM if not found by 'check_command pm2'
    if ! check_command "pm2"; then
        log_info "PM2 not found. Will attempt to install globally via npm."
        # This will be handled in npm global installs section
    fi


    if [ \${#MISSING_SYS_DEPS[@]} -ne 0 ]; then
        log_info "Missing system dependencies: \${MISSING_SYS_DEPS[*]}"
        log_info "Attempting installation using apt..."
        sudo apt-get update -y || log_warn "apt-get update failed. Trying to continue..."
        # Filter out npm/pip managed packages from apt install
        APT_DEPS=()
        for dep in "\${MISSING_SYS_DEPS[@]}"; do
            if [[ "\$dep" != "npm" && "\$dep" != "python3-pip" && "\$dep" != "pm2" ]]; then
                # python3-venv is often part of python3-dev or a specific package
                if [[ "\$dep" == "python3-venv" ]]; then
                    APT_DEPS+=("python3.\$(echo \$MIN_PYTHON_MINOR)-venv" "python3-venv") # Try specific and generic
                else
                    APT_DEPS+=("\$dep")
                fi
            fi
        done
        if [ \${#APT_DEPS[@]} -ne 0 ]; then
            sudo apt-get install -y --no-install-recommends \${APT_DEPS[*]} || {
                log_error "Failed to install some system dependencies: \${APT_DEPS[*]}. Please install them manually and restart."
                exit 1
            }
        fi
        log_info "System dependencies installation attempt complete."
    else
        log_info "Core system dependencies seem to be present."
    fi
    
    # Verify Python version
    if check_command "$PYTHON_CMD"; then
        CURRENT_PYTHON_VERSION=\$($PYTHON_CMD -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
        log_info "Python version: \$CURRENT_PYTHON_VERSION"
        if ! version_check "\$CURRENT_PYTHON_VERSION" "\$MIN_PYTHON_MAJOR.\$MIN_PYTHON_MINOR"; then
            log_error "Python version \$MIN_PYTHON_MAJOR.\$MIN_PYTHON_MINOR or higher is required. Found \$CURRENT_PYTHON_VERSION."
            exit 1
        fi
    else
        log_error "$PYTHON_CMD is not installed. Please install Python \$MIN_PYTHON_MAJOR.\$MIN_PYTHON_MINOR+."
        exit 1
    fi

    # Verify Node.js version (use the determined NODE_CMD)
    if check_command "$NODE_CMD"; then
        CURRENT_NODE_VERSION=\$(\$NODE_CMD -v | sed 's/v//') # Remove 'v' prefix
        log_info "Node.js version: \$CURRENT_NODE_VERSION"
        if ! version_check "\$CURRENT_NODE_VERSION" "\$MIN_NODE_MAJOR.0"; then # Add .0 for comparison
            log_error "Node.js version \$MIN_NODE_MAJOR or higher is required. Found \$CURRENT_NODE_VERSION."
            exit 1
        fi
    else
        log_error "$NODE_CMD (or nodejs) is not installed. Please install Node.js \$MIN_NODE_MAJOR+."
        exit 1
    fi
    
    # Install/Update PM2 globally if not already present or if installation failed earlier
    if ! check_command "pm2"; then
        log_step "[2/7] Installing/Updating PM2 globally via npm (sudo required)..."
        if sudo "$NPM_CMD" install -g pm2; then
            log_info "PM2 installed successfully globally."
        else
            log_error "Failed to install PM2 globally. Please try manually: 'sudo npm install -g pm2'"
            exit 1
        fi
    else
        log_info "PM2 is already installed."
    fi


    # 3. Backend Setup
    log_step "[3/7] Setting up Python Backend in ./backend/ ..."
    cd "\$INSTALL_DIR/backend" || { log_error "Backend directory not found!"; exit 1; }

    if [ ! -f "requirements.txt" ]; then
        log_error "requirements.txt not found in backend directory!"
        exit 1
    fi
    
    # Create and activate virtual environment
    if [ ! -d "venv" ]; then
        log_info "Creating Python virtual environment..."
        "$PYTHON_CMD" -m venv venv || { log_error "Failed to create venv."; exit 1; }
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
    deactivate # Deactivate for now, start scripts will activate it.
    cd "\$INSTALL_DIR"


    # 4. Frontend Setup
    log_step "[4/7] Setting up Node.js Frontend in ./frontend/ ..."
    cd "\$INSTALL_DIR/frontend" || { log_error "Frontend directory not found!"; exit 1; }

    if [ ! -f "package.json" ]; then
        log_error "package.json not found in frontend directory!"
        exit 1
    fi

    log_info "Installing Node.js dependencies from package.json..."
    "$NPM_CMD" install || { 
        log_error "Failed to install Node.js dependencies."
        exit 1
    }
    log_info "Node.js dependencies installed."

    log_info "Building React frontend (this may take a few minutes)..."
    "$NPM_CMD" run build || {
        log_error "React build failed. Please check errors above."
        exit 1
    }
    log_info "React frontend built successfully."
    cd "\$INSTALL_DIR"


    # 5. Ollama Check
    log_step "[5/7] Checking Ollama Installation..."
    DEFAULT_OLLAMA_MODEL=\$(grep OLLAMA_DEFAULT_MODEL "\$INSTALL_DIR/backend/.env.example" 2>/dev/null | cut -d '=' -f2)
    if [ -z "\$DEFAULT_OLLAMA_MODEL" ]; then DEFAULT_OLLAMA_MODEL="llama3"; fi # Fallback

    if check_command "ollama"; then
        log_info "Ollama is installed."
        OLLAMA_RUNNING=false
        if ollama list > /dev/null 2>&1; then
            OLLAMA_RUNNING=true
            log_info "Ollama is running and responding."
        else
            log_warn "Ollama is installed but not responding."
            # Attempting to start is complex and platform-dependent, so we'll skip for MVP installer
            # and rely on user to ensure it's running.
            log_warn "Please ensure 'ollama serve' is running in another terminal if you want to pull models now or use the agent."
        fi

        if \$OLLAMA_RUNNING; then
            if ! ollama list | grep -q "\$DEFAULT_OLLAMA_MODEL"; then
                log_warn "Default Ollama model '\$DEFAULT_OLLAMA_MODEL' (from .env.example) not found locally."
                read -p "Attempt to pull '\$DEFAULT_OLLAMA_MODEL' now? (y/N): " confirm_pull
                if [[ "\$confirm_pull" == [yY] || "\$confirm_pull" == [yY][eE][sS] ]]; then
                    log_info "Pulling '\$DEFAULT_OLLAMA_MODEL'... this may take some time."
                    if ollama pull "\$DEFAULT_OLLAMA_MODEL"; then
                        log_info "'\$DEFAULT_OLLAMA_MODEL' pulled successfully."
                    else
                        log_error "Failed to pull '\$DEFAULT_OLLAMA_MODEL'. Please try manually: ollama pull \$DEFAULT_OLLAMA_MODEL"
                    fi
                else
                    log_warn "Skipping model pull. Please ensure '\$DEFAULT_OLLAMA_MODEL' or your configured model (in backend/.env) is available in Ollama."
                fi
            else
                log_info "Default Ollama model '\$DEFAULT_OLLAMA_MODEL' (from .env.example) is available."
            fi
        else
             log_warn "Cannot check for models or pull new ones as Ollama service is not responding."
             log_warn "Please ensure Ollama is running and then manually pull your desired model, e.g., 'ollama pull \$DEFAULT_OLLAMA_MODEL'"
        fi
    else
        log_warn "Ollama command not found. The Unified AI Agent requires Ollama for its AI capabilities."
        log_warn "Please install Ollama from https://ollama.com/ and ensure a model (e.g., 'ollama pull \$DEFAULT_OLLAMA_MODEL') is downloaded and Ollama is running."
    fi

    # 6. Configuration File Setup (.env)
    log_step "[6/7] Setting up Configuration (.env file)..."
    cd "\$INSTALL_DIR/backend" || { log_error "Backend directory not found!"; exit 1; }
    if [ -f ".env.example" ]; then
        if [ -f ".env" ]; then
            log_info ".env file already exists. Skipping creation from .env.example."
            log_warn "Please ensure your existing .env file in ./backend/ has all necessary variables:"
            log_warn "FLASK_APP, FLASK_ENV, FLASK_RUN_PORT, SECRET_KEY, OLLAMA_BASE_URL, OLLAMA_DEFAULT_MODEL, CHROMA_DB_PATH, LOG_LEVEL, LOG_FILE, BASIC_AUTH_USERNAME, BASIC_AUTH_PASSWORD, BASIC_AUTH_ENABLED"
        else
            cp .env.example .env
            # Generate a new SECRET_KEY
            NEW_SECRET_KEY=\$(openssl rand -hex 32)
            sed -i "s|^SECRET_KEY=.*|SECRET_KEY=\$NEW_SECRET_KEY|" .env
            
            # Generate a new BASIC_AUTH_PASSWORD
            NEW_BASIC_AUTH_PASSWORD=\$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
            sed -i "s|^BASIC_AUTH_PASSWORD=.*|BASIC_AUTH_PASSWORD=\$NEW_BASIC_AUTH_PASSWORD|" .env
            
            log_info "Created .env file from .env.example in ./backend/."
            log_info "A new SECRET_KEY and a random BASIC_AUTH_PASSWORD have been generated."
            log_warn "The generated password will be displayed at the end of the installation."
            log_warn "Please also review OLLAMA_DEFAULT_MODEL in './backend/.env' if needed."
        fi
    else
        log_error ".env.example not found in backend. Cannot create .env configuration."
        exit 1
    fi
    cd "\$INSTALL_DIR"

    # 7. PM2 Setup for Backend
    log_step "[7/7] Setting up PM2 for the Backend..."
    # Create an ecosystem file for PM2 if it doesn't exist or provide one
    # For this MVP, we'll use a simple pm2 start command.
    # The backend/main.py is configured to be run by Gunicorn or Flask's dev server.
    # PM2 can manage the gunicorn process.
    # The .env file in backend/ will be read by Flask/Gunicorn.
    
    ECOSYSTEM_FILE="\$INSTALL_DIR/unified_agent_ecosystem.config.js"
    FLASK_APP_PORT=\$(grep FLASK_RUN_PORT "\$INSTALL_DIR/backend/.env" | cut -d '=' -f2)
    if [ -z "\$FLASK_APP_PORT" ]; then FLASK_APP_PORT=5050; fi # Default if not found

    log_info "Creating PM2 ecosystem file: \$ECOSYSTEM_FILE"
    cat << EOF > "\$ECOSYSTEM_FILE"
module.exports = {
  apps : [{
    name   : "unified-agent-backend",
    script : "\$INSTALL_DIR/backend/venv/bin/gunicorn", // Use gunicorn from venv
    args   : ["-w", "4", "-k", "gevent", "--bind", "0.0.0.0:\${FLASK_APP_PORT}", "main:app"], // Workers, worker class, bind, app module
    cwd    : "\$INSTALL_DIR/backend/", // Set CWD to backend for main:app and .env
    interpreter: "\$INSTALL_DIR/backend/venv/bin/python", // Not strictly needed if script is python executable from venv
    exec_mode : "cluster", // Or "fork"
    instances : 1, // Or "max" for cluster mode
    autorestart: true,
    watch    : false, // Set to true or path array for auto-reload on changes
    max_memory_restart: '1G',
    env: {
      // PM2 can also set env vars here, but .env in backend/ should be primary
      // FLASK_ENV: "production", // Override if needed
    },
    out_file: "\$INSTALL_DIR/logs/pm2-backend-out.log",
    error_file: "\$INSTALL_DIR/logs/pm2-backend-err.log",
    log_date_format: "YYYY-MM-DD HH:mm:ss Z"
  }]
};
EOF

    log_info "PM2 ecosystem file created."
    log_info "Attempting to start the Unified AI Agent backend via PM2..."
    if pm2 start "\$ECOSYSTEM_FILE"; then
        log_info "Backend successfully started with PM2."
        pm2 save # Persist the process list
        log_info "PM2 process list saved."
    else
        log_error "Failed to start backend with PM2. Please try starting it manually: pm2 start \$ECOSYSTEM_FILE"
        log_warn "Ensure Ollama is running and the model is available before manual start."
    fi
    # log_warn "To view logs: pm2 logs unified-agent-backend" # This info will be in final instructions

    # --- Final Instructions ---
    log_step "Installation Complete!"
    echo ""
    log_info "--------------------------------------------------------------------"
    log_info "Unified AI Agent MVP installation finished."
    log_info "--------------------------------------------------------------------"
    echo ""

    # Display generated password
    GENERATED_PASSWORD=\$(grep BASIC_AUTH_PASSWORD "\$INSTALL_DIR/backend/.env" | cut -d '=' -f2)
    GENERATED_USERNAME=\$(grep BASIC_AUTH_USERNAME "\$INSTALL_DIR/backend/.env" | cut -d '=' -f2)
    log_info "IMPORTANT - Credentials for Web UI Access:"
    log_info "Username:         ${COLOR_WARN}\$GENERATED_USERNAME${COLOR_RESET}"
    log_info "Generated Password: ${COLOR_WARN}\$GENERATED_PASSWORD${COLOR_RESET}"
    log_info "Please save this password securely. You can change it in \$INSTALL_DIR/backend/.env"
    log_info "--------------------------------------------------------------------"
    echo ""
    
    log_info "NEXT STEPS:"
    echo ""
    log_info "1. Review Other Configuration (Optional):"
    log_info "   Check settings in ${COLOR_WARN}\$INSTALL_DIR/backend/.env${COLOR_RESET}"
    log_info "   (e.g., OLLAMA_DEFAULT_MODEL, FLASK_RUN_PORT if conflicts)."
    echo ""
    log_info "2. Ensure Ollama is Running & Model Available:"
    log_info "   - If not already running, start Ollama: ${COLOR_WARN}ollama serve${COLOR_RESET}"
    log_info "   - If the default model (or your configured one) was not pulled during installation,"
    log_info "     ensure it's available: ${COLOR_WARN}ollama pull \$(grep OLLAMA_DEFAULT_MODEL "\$INSTALL_DIR/backend/.env" | cut -d '=' -f2)${COLOR_RESET}"
    echo ""
    log_info "3. Manage the Application:"
    log_info "   The backend application should have been started by PM2."
    log_info "   Use the helper scripts in ${COLOR_WARN}\$INSTALL_DIR/${COLOR_RESET} to manage the agent:"
    log_info "     Start: ${COLOR_WARN}./start_agent.sh${COLOR_RESET}"
    log_info "     Stop:  ${COLOR_WARN}./stop_agent.sh${COLOR_RESET}"
    echo ""
    log_info "4. Access the Web Interface:"
    log_info "   The backend API will be available at: ${COLOR_WARN}http://localhost:\$(grep FLASK_RUN_PORT "\$INSTALL_DIR/backend/.env" | cut -d '=' -f2)${COLOR_RESET}"
    log_info "   For development (after 'cd frontend && npm start'), the UI is usually at http://localhost:3000 (proxies to backend)."
    log_info "   For production (using the built frontend), you'll need a static server for '${COLOR_WARN}\$INSTALL_DIR/frontend/build/${COLOR_RESET}'"
    log_info "   and potentially a reverse proxy to the backend API."
    echo ""
    log_info "View logs with: ${COLOR_WARN}pm2 logs unified-agent-backend${COLOR_RESET} or check files in ${COLOR_WARN}\$INSTALL_DIR/logs/${COLOR_RESET}"
    echo ""
    log_info "--------------------------------------------------------------------"
    
    # Make helper scripts executable
    chmod +x "\$INSTALL_DIR/start_agent.sh" "\$INSTALL_DIR/stop_agent.sh"
    log_info "Helper scripts start_agent.sh and stop_agent.sh have been made executable."

}

# --- Execute Main Function ---
main "\$@"

exit 0
```
