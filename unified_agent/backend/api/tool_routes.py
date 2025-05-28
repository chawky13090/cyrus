import logging
from flask import request, jsonify, current_app
from . import api_bp # Assuming this is the main API blueprint from api/__init__.py
from ..tools.nmap_tool import run_nmap_scan
from ..tools.ssh_tool import execute_ssh_command
from ..utils.auth import auth_required

logger = logging.getLogger(__name__)

@api_bp.route('/tools/nmap/scan', methods=['POST'])
@auth_required
def nmap_scan_route():
    # TODO: Add authentication/authorization check here later
    data = request.get_json()
    if not data:
        return jsonify({"error": "No data provided"}), 400

    target = data.get('target')
    options = data.get('options', '-T4 -F') # Default options

    if not target:
        return jsonify({"error": "Target for Nmap scan is required."}), 400

    logger.info(f"Nmap scan API called for target: {target}, options: {options}")
    # Note: Running scans can take time. Consider async task for long scans in future.
    scan_result = run_nmap_scan(target, options)
    
    if "error" in scan_result:
         # Determine appropriate status code based on error type
        if "Nmap execution error" in scan_result["error"]:
            return jsonify(scan_result), 500 # Server-side issue (Nmap not installed or failed)
        else: # e.g. invalid target
            return jsonify(scan_result), 400
    return jsonify(scan_result), 200


@api_bp.route('/tools/ssh/execute', methods=['POST'])
@auth_required
def ssh_execute_route():
    # TODO: Add authentication/authorization check here later
    data = request.get_json()
    if not data:
        return jsonify({"error": "No data provided"}), 400

    hostname = data.get('hostname')
    command = data.get('command')
    username = data.get('username')
    port = data.get('port', 22)
    password = data.get('password') # Handle with extreme care
    key_filename = data.get('key_filename') # Path to key file on the server running Flask

    if not all([hostname, command, username]):
        return jsonify({"error": "Missing required parameters (hostname, command, username)."}), 400
    if not password and not key_filename:
         return jsonify({"error": "Missing authentication method (password or key_filename)."}), 400


    logger.info(f"SSH execute API called for host: {hostname}, user: {username}, command: {command[:30]}...")
    
    # SECURITY WARNING: Storing or transmitting plain passwords is a major risk.
    # This is a simplified MVP. Real applications need secure credential management (e.g., Vault, encrypted storage, or client-side key handling if possible).
    if password:
        logger.warning("API /tools/ssh/execute received a password. This is insecure for production.")
        
    ssh_result = execute_ssh_command(hostname, port, username, command, password=password, key_filename=key_filename)
    
    if "error" in ssh_result:
        if "authentication failed" in ssh_result["error"].lower():
            return jsonify(ssh_result), 401 # Unauthorized
        elif "connection error" in ssh_result["error"].lower():
            return jsonify(ssh_result), 503 # Service unavailable (cannot connect)
        else:
            return jsonify(ssh_result), 500 # Other server-side errors
    return jsonify(ssh_result), 200
```
