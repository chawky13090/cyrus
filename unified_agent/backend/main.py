import logging
from flask import Flask
from flask_cors import CORS
from .config import Config
from .app_setup import setup_logging, init_extensions
from .api import api_bp # Import the main API blueprint

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config) # Load config from config.py

    # Setup logging as early as possible
    # setup_logging(app.config) # app.config is a wrapper, pass the Config object directly
    setup_logging(Config) 
    
    logger = logging.getLogger(__name__)
    logger.info(f"Unified Agent backend starting in {app.config['FLASK_ENV']} mode...")

    # Initialize CORS - adjust origins for production if needed
    CORS(app, resources={r"/api/*": {"origins": "*"}}) # Example: allow all for /api prefix

    # Initialize extensions (like ChromaDB)
    with app.app_context(): # Extensions might need app context
        init_extensions(app)

    # Register blueprints
    app.register_blueprint(api_bp, url_prefix='/api')
    
    logger.info("Flask app created, extensions initialized, blueprints registered.")
    logger.info(f"Ollama Base URL: {app.config['OLLAMA_BASE_URL']}")
    logger.info(f"Default Model: {app.config['OLLAMA_DEFAULT_MODEL']}")
    # Corrected to use resolved path if CHROMA_DB_PATH was relative
    # However, app.config['CHROMA_DB_PATH'] holds the original value.
    # The actual path used by ChromaDB is logged in init_extensions.
    # For consistency, we might want to store the resolved path in app.config if needed elsewhere.
    logger.info(f"ChromaDB Path (from .env): {app.config['CHROMA_DB_PATH']}")


    return app

app = create_app() # Create the app instance for Gunicorn or direct run

if __name__ == '__main__':
    # This is for direct execution (python main.py), not for Gunicorn
    # Use the logger from the app context after it's fully set up
    app.logger.info(f"Starting Flask development server on port {app.config['FLASK_RUN_PORT']}...")
    app.run(host='0.0.0.0', port=app.config['FLASK_RUN_PORT'])
```
