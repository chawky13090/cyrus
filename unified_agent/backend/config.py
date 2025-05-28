import os
from dotenv import load_dotenv

# Load .env file from the backend directory
dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(dotenv_path)

class Config:
    FLASK_APP = os.getenv('FLASK_APP', 'main:app')
    FLASK_ENV = os.getenv('FLASK_ENV', 'development')
    FLASK_RUN_PORT = int(os.getenv('FLASK_RUN_PORT', 5050))
    SECRET_KEY = os.getenv('SECRET_KEY', 'a_default_secret_key') # Fallback default

    OLLAMA_BASE_URL = os.getenv('OLLAMA_BASE_URL', 'http://localhost:11434')
    OLLAMA_DEFAULT_MODEL = os.getenv('OLLAMA_DEFAULT_MODEL', 'llama3')

    CHROMA_DB_PATH = os.getenv('CHROMA_DB_PATH', './unified_agent_chroma_db')
    
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO').upper()
    LOG_FILE = os.getenv('LOG_FILE', '../logs/backend.log')

    # Basic Authentication
    BASIC_AUTH_USERNAME = os.getenv('BASIC_AUTH_USERNAME', 'admin')
    BASIC_AUTH_PASSWORD = os.getenv('BASIC_AUTH_PASSWORD', 'defaultpassword')
    BASIC_AUTH_ENABLED = os.getenv('BASIC_AUTH_ENABLED', 'True').lower() == 'true'

# Ensure the log directory exists
# The log file path is relative to the backend directory.
# So, we need to get the absolute path of the backend directory first.
_backend_dir = os.path.dirname(__file__)
_log_file_abs_path = os.path.join(_backend_dir, Config.LOG_FILE)
log_dir = os.path.dirname(_log_file_abs_path)

if not os.path.exists(log_dir):
    os.makedirs(log_dir, exist_ok=True)
