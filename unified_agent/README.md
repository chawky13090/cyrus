# Unified AI Agent - MVP v1.0

Welcome to the Unified AI Agent MVP! This project provides an AI-powered chat interface with integrated NetOps tools (Nmap, SSH) and persistent memory, designed for local deployment and interaction with Ollama models.

## MVP Features
*   **Centralized Chat Interface:** A web UI (React) for interacting with a local LLM via a Python Flask backend.
*   **Ollama Integration:** Leverages local Ollama models for generating AI responses.
*   **Persistent Conversation Memory:** Uses ChromaDB to store conversation history.
*   **NetOps Tool Integration:**
    *   **Nmap:** Perform network scans directly from the UI.
    *   **SSH:** Execute commands on remote hosts via SSH from the UI.
*   **Basic Security:** The web interface is protected by Basic Authentication.
*   **Automated Installation:** A comprehensive installer script (`installer.sh`) for setting up dependencies and configuring the application.
*   **Easy Management:** Includes `start_agent.sh` and `stop_agent.sh` scripts for day-to-day operation.
*   **Comprehensive Logging:** Backend actions, API access, and errors are logged.

## Prerequisites
*   A Linux system (tested on Debian/Ubuntu-based systems).
*   `sudo` privileges for system dependency installation.
*   Ollama installed and running is highly recommended. If not, the installer will guide you. (See: [https://ollama.com/](https://ollama.com/))
*   At least one Ollama model pulled (e.g., `ollama pull llama3`). The installer can help with this for the default model.
*   `curl`, `git` (usually pre-installed on most Linux systems).
*   `nmap` command-line tool (the installer will attempt to install this).

## Installation & Setup

1.  **Clone or Download the Agent:**
    *   If you have git: `git clone <repository_url>`
    *   Or, download and extract the `unified_agent` source code archive.
    *   Navigate into the `unified_agent` directory: `cd unified_agent`

2.  **Run the Installer:**
    *   Make the installer executable: `chmod +x installer.sh`
    *   Execute the installer: `./installer.sh`
    *   The script will guide you through:
        *   System dependency checks and installation (Python, Node.js, npm, nmap, PM2).
        *   Python backend setup (virtual environment, pip packages).
        *   Node.js frontend setup (npm packages, production build).
        *   Ollama checks (and an option to pull the default model).
        *   Configuration of `backend/.env` (including generation of a random `SECRET_KEY` and `BASIC_AUTH_PASSWORD`).
        *   Setup of PM2 for managing the backend application.
        *   Automatic start of the backend service via PM2.

3.  **Post-Installation - IMPORTANT:**
    *   **Note Your Credentials:** At the end of the installation, the script will display the **generated username and password** for Basic Authentication. Please save these securely. You can change them later by editing `unified_agent/backend/.env`.
    *   **Verify Ollama:** Ensure Ollama is running (`ollama serve`) and the model specified in `unified_agent/backend/.env` (default is `llama3`) is available. The installer attempts to help with this, but manual verification is good.
    *   **Firewall:** If you are accessing the agent from another machine, ensure your firewall allows connections to the port used by the backend (default: 5050, as specified in `backend/.env` and used by PM2).

## Managing the Agent

Located in the `unified_agent/` directory:

*   **Start the Agent:**
    ```bash
    ./start_agent.sh
    ```
    This script uses PM2 to start/restart the backend service. It also performs basic checks for Ollama.

*   **Stop the Agent:**
    ```bash
    ./stop_agent.sh
    ```
    This script stops and removes the backend service from PM2.

*   **View Logs:**
    *   PM2 logs for the backend: `pm2 logs unified-agent-backend`
    *   Application logs: Check files in `unified_agent/logs/` (e.g., `backend.log`).

## Accessing the Web Interface

*   The backend API runs on the port specified in `unified_agent/backend/.env` (default is `FLASK_RUN_PORT=5050`).
*   The installer *builds* the frontend static files into `unified_agent/frontend/build/`.
*   **For development:** You can run the React development server from the `unified_agent/frontend/` directory:
    ```bash
    cd frontend
    npm start 
    ```
    This will typically open the UI in your browser at `http://localhost:3000`. The `package.json` includes a proxy to the backend port (5050) to handle API requests.
*   **For production-like access (after running installer):** The installer does not set up a production web server for the frontend static files. You would typically use a web server like Nginx or Caddy to:
    1.  Serve the static files from `unified_agent/frontend/build/`.
    2.  Reverse proxy API requests (e.g., `/api/*`) to the backend service running on its port (e.g., `http://localhost:5050`).
    Access will then be through your configured web server's address.

## Using the Agent

1.  Open the web interface in your browser.
2.  You will be prompted for the username and password (Basic Authentication). Use the credentials provided at the end of the installation or as configured in `backend/.env`.
3.  **Chat:** Use the chat interface to interact with the AI model.
4.  **Nmap Scan:**
    *   Go to the "Nmap Scan" section.
    *   Enter the target IP, hostname, or range.
    *   Specify Nmap options (default is `-T4 -F`).
    *   Click "Run Scan". Results will appear below.
5.  **SSH Command Execution:**
    *   Go to the "SSH Command" section.
    *   Enter hostname, port (default 22), username, and password.
        *   **Security Warning:** Using passwords for SSH in this manner is for MVP convenience. For better security, use SSH keys. Key-based auth from the browser is complex; this tool sends credentials to the backend.
    *   Enter the command to execute.
    *   Click "Execute Command". Output (stdout/stderr) and exit status will be displayed.

## Future Vision
This MVP is the first step towards a more advanced AI agent. Future enhancements could include:
*   More sophisticated UI/UX with dashboards and visualizations.
*   Integration of more NetOps and Security tools.
*   Advanced memory management and knowledge base capabilities.
*   Workflow automation features.
*   Enhanced security features (e.g., role-based access control, SSH key management).
*   Mechanisms to support continuous learning and model refinement.

## Troubleshooting
*   Check logs in `unified_agent/logs/` and PM2 logs (`pm2 logs unified-agent-backend`).
*   Ensure Ollama is running and the specified model is available.
*   Verify settings in `unified_agent/backend/.env`.
*   Ensure system dependencies (especially `nmap` command-line tool) are correctly installed.
```
