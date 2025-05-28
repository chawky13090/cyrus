import paramiko
import logging

logger = logging.getLogger(__name__)

def execute_ssh_command(hostname: str, port: int, username: str, command: str, password: str = None, key_filename: str = None, timeout: int = 15):
    '''
    Executes an SSH command on a remote host.
    :param hostname: The target hostname or IP address.
    :param port: SSH port (usually 22).
    :param username: Username for SSH login.
    :param command: The command to execute.
    :param password: Password for authentication (use with caution).
    :param key_filename: Path to private key file for authentication.
    :param timeout: Connection and command execution timeout in seconds.
    :return: Dictionary with command output or error information.
    '''
    logger.info(f"Attempting SSH to {username}@{hostname}:{port} to run command: '{command[:50]}...'")

    if not password and not key_filename:
        logger.error("SSH command execution requires either a password or a key file.")
        return {"error": "Authentication method required (password or key file)."}
    
    # Security Warning if password is used
    if password:
        logger.warning("SSH connection using password. For production, key-based authentication is strongly recommended.")

    client = None
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy()) # Auto-accept host key for MVP

        client.connect(
            hostname=hostname,
            port=port,
            username=username,
            password=password, # Will be None if key_filename is used primarily
            key_filename=key_filename,
            timeout=timeout,
            allow_agent=False, # For security, don't use ssh-agent by default
            look_for_keys=False # If key_filename is specified, don't look for others
        )

        stdin, stdout, stderr = client.exec_command(command, timeout=timeout)
        output = stdout.read().decode('utf-8', errors='replace').strip()
        error_output = stderr.read().decode('utf-8', errors='replace').strip()
        exit_status = stdout.channel.recv_exit_status() # Get exit status of the command

        logger.info(f"SSH command executed on {hostname}. Exit status: {exit_status}")
        
        if error_output and exit_status != 0:
             logger.warning(f"SSH command stderr on {hostname}: {error_output}")
             # Some commands output to stderr for info, so check exit_status too
             return {"hostname": hostname, "command": command, "stdout": output, "stderr": error_output, "exit_status": exit_status, "warning": "Command may have failed or produced errors."}

        return {"hostname": hostname, "command": command, "stdout": output, "stderr": error_output, "exit_status": exit_status}

    except paramiko.AuthenticationException:
        logger.error(f"SSH authentication failed for {username}@{hostname}:{port}.")
        return {"error": "SSH authentication failed. Check credentials."}
    except paramiko.SSHException as ssh_ex:
        logger.error(f"SSH connection error for {username}@{hostname}:{port}: {ssh_ex}")
        return {"error": f"SSH connection error: {ssh_ex}"}
    except Exception as e:
        logger.error(f"Unexpected error during SSH execution on {hostname}: {e}", exc_info=True)
        return {"error": f"An unexpected error occurred: {e}"}
    finally:
        if client:
            client.close()
```
