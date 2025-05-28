import logging
import os
from logging.handlers import RotatingFileHandler
from flask import current_app
from .config import Config

# ChromaDB client placeholder - will be initialized in main.py
chroma_collection = None

def setup_logging(app_config: Config):
    # Ensure log directory exists (config.py tries, but good to double check here)
    # The log file path from Config is relative to the backend directory.
    # os.path.dirname(__file__) gives the directory of app_setup.py (i.e., backend)
    backend_dir = os.path.dirname(__file__)
    log_file_path = os.path.abspath(os.path.join(backend_dir, app_config.LOG_FILE))
    
    log_dir = os.path.dirname(log_file_path)
    if not os.path.exists(log_dir):
        os.makedirs(log_dir, exist_ok=True)

    # Basic logging configuration
    logging.basicConfig(
        level=getattr(logging, app_config.LOG_LEVEL, logging.INFO),
        format='%(asctime)s - %(name)s - %(levelname)s - %(module)s.%(funcName)s:%(lineno)d - %(message)s',
        handlers=[
            RotatingFileHandler(log_file_path, maxBytes=1024*1024*5, backupCount=2), # 5MB per file, 2 backups
            logging.StreamHandler() # Also log to console
        ]
    )
    # Silence werkzeug's default logger if needed, or set its level
    # logging.getLogger('werkzeug').setLevel(logging.ERROR) 
    logger = logging.getLogger(__name__)
    logger.info(f"Logging setup complete. Log level: {app_config.LOG_LEVEL}, Log file: {log_file_path}")

def init_extensions(app):
    global chroma_collection
    from .utils import db as chroma_utils # Defer import
    
    # app.config is already loaded from Config object which resolves CHROMA_DB_PATH
    # relative to .env if not absolute.
    # If CHROMA_DB_PATH is like './unified_agent_chroma_db', it's relative to backend dir.
    db_path_from_config = app.config['CHROMA_DB_PATH']
    
    # app.root_path is the 'backend' directory if main.py is in 'backend'
    # For paths like './some_db' in .env, they are relative to where the app runs or where .env is.
    # If .env is in backend/, and CHROMA_DB_PATH is ./something, then it's backend/something
    if not os.path.isabs(db_path_from_config):
        db_path = os.path.join(app.root_path, db_path_from_config)
    else:
        db_path = db_path_from_config
            
    app.logger.info(f"Attempting to initialize ChromaDB at: {db_path}")
    chroma_collection = chroma_utils.initialize_chromadb(db_path, "unified_agent_conversations")
    if chroma_collection is None:
        app.logger.error("Failed to initialize ChromaDB collection. Conversation history will not be persistent.")
    else:
        app.logger.info("ChromaDB collection initialized successfully.")
    
    # Make it accessible via app context if needed, though direct import is also possible now
    app.extensions['chroma_collection'] = chroma_collection

```
