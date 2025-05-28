from functools import wraps
from flask import request, Response, current_app
import logging

logger = logging.getLogger(__name__)

def check_auth(username, password):
    '''This function is called to check if a username /
    password combination is valid.'''
    return username == current_app.config['BASIC_AUTH_USERNAME'] and \
           password == current_app.config['BASIC_AUTH_PASSWORD']

def authenticate():
    '''Sends a 401 response that enables basic auth'''
    return Response(
        'Could not verify your access level for that URL.\n'
        'You have to login with proper credentials', 401,
        {'WWW-Authenticate': 'Basic realm="Login Required"'})

def auth_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not current_app.config['BASIC_AUTH_ENABLED']:
            return f(*args, **kwargs) # Bypass auth if disabled

        auth = request.authorization
        if not auth or not check_auth(auth.username, auth.password):
            logger.warning(f"Unauthorized access attempt to {request.path} from IP {request.remote_addr}")
            return authenticate()
        
        # Log successful access, but be mindful of log verbosity
        # For MVP, logging every successful authenticated access might be too much.
        # Consider logging only if a certain log level (e.g., DEBUG) is set.
        if current_app.config.get('LOG_LEVEL') == 'DEBUG': # Use .get for safety
            logger.debug(f"Authorized access to {request.path} by user '{auth.username}' from IP {request.remote_addr}")
        
        return f(*args, **kwargs)
    return decorated
```
