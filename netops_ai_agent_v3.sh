#!/bin/bash
# NetOps AI Agent v3 Installer Script

echo "Creating backend directories..."
mkdir -p backend/api backend/utils

echo "Creating backend/utils/vector_db.py..."
cat << 'EOF' > backend/utils/vector_db.py
import chromadb
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

collection = None
db_path = "./chroma_db_netops" # Example path

def init_chroma():
    global collection
    try:
        logger.info(f"Attempting to initialize ChromaDB at {db_path}...")
        chroma_client = chromadb.PersistentClient(path=db_path)
        collection = chroma_client.get_or_create_collection(name="netops_collection")
        logger.info(f"ChromaDB initialized successfully. Collection: {collection.name}")
        # Test add (optional, for immediate feedback)
        collection.add(ids=["test_id"], documents=["test_doc"], metadatas=[{"source": "initialization"}])
        logger.info("Test document added to ChromaDB.")
        query_results = collection.get(ids=["test_id"])
        if not query_results or not query_results.get("documents"):
            logger.error("Failed to retrieve test document from ChromaDB after initialization.")
            # collection = None # Critical: Ensure collection is None if test fails
            # For now, let's assume get_or_create_collection is the primary point of failure detection for collection usability
    except Exception as e:
        logger.error(f"Failed to initialize ChromaDB at {db_path}: {e}", exc_info=True)
        collection = None # Ensure collection is None on error

def add_document(doc_id, document, metadata):
    if collection is None:
        logger.error("ChromaDB collection not initialized. Cannot add document.")
        return
    try:
        collection.add(ids=[doc_id], documents=[document], metadatas=[metadata])
        logger.info(f"Document {doc_id} added to ChromaDB.")
    except Exception as e:
        logger.error(f"Failed to add document {doc_id} to ChromaDB: {e}", exc_info=True)

# Example of initializing Chroma when this module is loaded
# In a real app, this might be called from main.py or app factory
init_chroma()
EOF

echo "Creating backend/api/chat.py..."
cat << 'EOF' > backend/api/chat.py
from flask import Blueprint, request, jsonify
import logging
import requests
import os

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Import ChromaDB collection
from utils.vector_db import collection as chroma_collection

chat_bp = Blueprint('chat_bp', __name__)

# Simulate getting current model (replace with actual logic if any)
current_model_name = os.getenv("OLLAMA_MODEL", "mistral:latest") 

@chat_bp.route('/chat/', methods=['POST'])
def handle_chat():
    # Check if ChromaDB is available
    if chroma_collection is None:
        logger.error("CRITICAL: ChromaDB collection is not available in chat_bp. Aborting chat request.")
        return jsonify({"error": "Chat database (ChromaDB) is not initialized. Please check backend startup logs for details."}), 503 # Service Unavailable

    data = request.get_json()
    user_message = data.get('message')
    # chat_id = data.get('chat_id') # Assuming chat_id might be used later

    if not user_message:
        return jsonify({"error": "No message provided"}), 400

    logger.info(f"Received message: {user_message} for model: {current_model_name}")

    try:
        # Interaction with Ollama
        ollama_api_url = os.getenv("OLLAMA_API_URL", "http://localhost:11434/api/generate")
        
        payload = {
            "model": current_model_name,
            "prompt": user_message,
            "stream": False  # Keep stream false for simple request/response
        }
        logger.info(f"Sending payload to Ollama: {payload}")

        response = requests.post(ollama_api_url, json=payload, timeout=60) # Increased timeout

        if response.status_code != 200:
            error_message = f"Ollama API error (model: {current_model_name})"
            ollama_error_details = response.text # Default if JSON parsing fails or no 'error' field
            try:
                json_response = response.json()
                ollama_error_details = json_response.get("error", response.text)
                error_message += f": {ollama_error_details}"
            except ValueError: # Includes JSONDecodeError
                error_message += f": Non-JSON response - {response.text[:100]}" # Truncate long non-JSON responses

            logger.error(f"Ollama API returned status code {response.status_code}. Message: {error_message}")

            if response.status_code == 404: # Often "model not found"
                # Specific message for model not found, including the model name attempted
                return jsonify({"error": f"Ollama: Model '{current_model_name}' not found. Please ensure it's pulled and available."}), 422 # Unprocessable Entity
            elif response.status_code == 400: # Bad request to Ollama
                 return jsonify({"error": f"Ollama: Bad request. Details: {ollama_error_details}"}), 400
            else: # Other server-side errors from Ollama or connectivity issues
                return jsonify({"error": error_message}), 502 # Bad Gateway (treating Ollama as upstream)
        
        ollama_response_data = response.json()
        assistant_response = ollama_response_data.get("response", "No response field from Ollama.")

        # Example of using ChromaDB (though not fully implemented here for brevity)
        # if chroma_collection:
        #     add_document(f"user_{chat_id}_{len(history)}", user_message, {"type": "user"})
        #     add_document(f"asst_{chat_id}_{len(history)}", assistant_response, {"type": "assistant"})

        return jsonify({"response": assistant_response})

    except requests.exceptions.Timeout:
        logger.error(f"Timeout connecting to Ollama API at {ollama_api_url}")
        return jsonify({"error": "Connection to Ollama API timed out"}), 504 # Gateway Timeout
    except requests.exceptions.RequestException as e:
        logger.error(f"Error connecting to Ollama API: {e}", exc_info=True)
        return jsonify({"error": f"Could not connect to Ollama API: {e}"}), 503 # Service Unavailable
    except Exception as e:
        logger.error(f"An unexpected error occurred in handle_chat: {e}", exc_info=True)
        return jsonify({"error": "An internal server error occurred"}), 500
EOF

echo "Creating frontend/src/App.js (minimal placeholder)..."
mkdir -p frontend/src
cat << 'EOF' > frontend/src/App.js
// Minimal App.js placeholder for installer script structure
console.log("App.js placeholder");
EOF

echo "NetOps AI Agent v3 Installer Script Created (with placeholders)"
# Placeholder for other parts of the script (nginx setup, systemd service, etc.)
