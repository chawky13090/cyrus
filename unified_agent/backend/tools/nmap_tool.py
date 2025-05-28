import nmap
import logging

logger = logging.getLogger(__name__)

def run_nmap_scan(target: str, options: str = '-T4 -F'):
    '''
    Runs an Nmap scan on the given target with specified options.
    :param target: The target IP address, hostname, or range.
    :param options: Nmap options string (e.g., '-T4 -F', '-sV -p 1-65535').
    :return: Dictionary with scan results or error information.
    '''
    logger.info(f"Starting Nmap scan on target: {target} with options: {options}")
    try:
        nm = nmap.PortScanner()
        # Ensure target and options are strings and not excessively long to avoid issues
        if not isinstance(target, str) or len(target) > 255:
            logger.error(f"Invalid target for Nmap scan: {target}")
            return {"error": "Invalid target specified."}
        if not isinstance(options, str) or len(options) > 255:
            logger.warning(f"Nmap options may be too long or invalid: {options}. Using default '-T4 -F'.")
            options = '-T4 -F' # Fallback to default if options seem problematic

        # The nmap.PortScanner().scan() method can raise nmap.nmap.PortScannerError
        # if nmap is not installed or found in path.
        # This should be handled by the installer ensuring nmap client is present.
        scan_results = nm.scan(hosts=target, arguments=options)
        
        # Process results for easier consumption
        processed_results = {}
        if 'scan' in scan_results:
            for host, result in scan_results['scan'].items():
                processed_results[host] = {
                    'hostname': result.get('hostnames', [{}])[0].get('name', 'N/A') if result.get('hostnames') else 'N/A',
                    'state': result.get('status', {}).get('state', 'N/A'),
                    'protocols': {}
                }
                for proto in result.get('tcp', {}): # Example for TCP, extend for UDP etc.
                    if 'tcp' not in processed_results[host]['protocols']:
                        processed_results[host]['protocols']['tcp'] = {}
                    processed_results[host]['protocols']['tcp'][proto] = result['tcp'][proto]
                for proto in result.get('udp', {}): # Example for UDP
                    if 'udp' not in processed_results[host]['protocols']:
                        processed_results[host]['protocols']['udp'] = {}
                    processed_results[host]['protocols']['udp'][proto] = result['udp'][proto]
        
        logger.info(f"Nmap scan completed for target: {target}")
        return {"target": target, "options": options, "results": processed_results, "raw_results": scan_results}

    except nmap.PortScannerError as e:
        logger.error(f"Nmap execution error for target {target}: {e}. Is Nmap installed and in PATH?")
        return {"error": f"Nmap execution error: {e}. Ensure Nmap is installed on the server."}
    except Exception as e:
        logger.error(f"Unexpected error during Nmap scan for target {target}: {e}", exc_info=True)
        return {"error": f"An unexpected error occurred: {e}"}

```
