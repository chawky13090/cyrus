import logging
import requests
from flask import request, jsonify, current_app
from . import api_bp # Import the blueprint
# Assuming app_setup.chroma_collection is the way to access it, or pass via app.extensions
# For simplicity with current structure, let's try importing the global from app_setup
from ..app_setup import chroma_collection
from ..utils.db import store_conversation, get_conversation_history
from ..utils.auth import auth_required


logger = logging.getLogger(__name__)

@api_bp.route('/chat', methods=['POST'])
@auth_required
def handle_chat():
    data = request.get_json()
    if not data:
        logger.warn("Chat request with no JSON data.")
        return jsonify({"error": "No data provided"}), 400

    user_message = data.get("message")
    session_id = data.get("session_id", "default_session") # Frontend should send this

    if not user_message:
        logger.warn(f"Chat request for session {session_id} with no message.")
        return jsonify({"error": "No message provided"}), 400

    if chroma_collection is None:
        logger.error("CRITICAL: ChromaDB collection is not available. Aborting chat request.")
        return jsonify({"error": "Chat database is not initialized. Please check backend logs."}), 503

    # Optional: Retrieve some history for context (e.g., last N messages)
    # history_context = get_conversation_history(chroma_collection, session_id, limit=5)
    # formatted_context = "\n".join([f"{item['metadata']['role']}: {item['message']}" for item in history_context])
    # prompt_message = f"{formatted_context}\nuser: {user_message}\nassistant:"
    prompt_message = user_message # Simple prompt for now

    ollama_url = current_app.config['OLLAMA_BASE_URL']
    model_name = current_app.config['OLLAMA_DEFAULT_MODEL']
    ollama_api_endpoint = f"{ollama_url}/api/generate"

    payload = {
        "model": model_name,
        "prompt": prompt_message,
        "stream": False # For MVP, non-streamed response
    }
    
    logger.info(f"Sending chat request to Ollama (model: {model_name}) for session {session_id}...")
    try:
        response = requests.post(ollama_api_endpoint, json=payload, timeout=60) # 60s timeout

        if response.status_code != 200:
            error_details = response.text
            try:
                json_resp = response.json()
                error_details = json_resp.get("error", response.text)
            except ValueError: # Not JSON
                pass
            
            logger.error(f"Ollama API error (model: {model_name}, status: {response.status_code}): {error_details}")
            status_code_to_return = 502 # Bad Gateway by default
            if response.status_code == 404: # Model not found
                status_code_to_return = 422 # Unprocessable Entity
            elif response.status_code == 400: # Bad request from our side
                status_code_to_return = 400
            
            return jsonify({"error": f"Ollama error: {error_details}"}), status_code_to_return

        ollama_data = response.json()
        ai_response = ollama_data.get("response", "Sorry, I could not generate a response.").strip()
        
        # Store conversation
        store_conversation(chroma_collection, session_id, user_message, ai_response, model_name)

        logger.info(f"Successfully processed chat for session {session_id}. AI response: {ai_response[:50]}...")
        return jsonify({"response": ai_response, "session_id": session_id})

    except requests.exceptions.Timeout:
        logger.error(f"Ollama request timed out for model {model_name} (session {session_id}).")
        return jsonify({"error": "Request to AI model timed out."}), 504 # Gateway Timeout
    except requests.exceptions.RequestException as e:
        logger.error(f"Error connecting to Ollama (model: {model_name}, session: {session_id}): {e}")
        return jsonify({"error": f"Could not connect to AI model service: {str(e)}"}), 503 # Service Unavailable
    except Exception as e:
        logger.error(f"Unexpected error in chat handler (session {session_id}): {e}", exc_info=True)
        return jsonify({"error": "An internal server error occurred."}), 500


@api_bp.route('/chat/history/<session_id>', methods=['GET'])
@auth_required
def get_history_route(session_id):
    if chroma_collection is None:
        logger.error("CRITICAL: ChromaDB collection is not available for history request.")
        return jsonify({"error": "Chat database is not initialized."}), 503
        
    history = get_conversation_history(chroma_collection, session_id)
    return jsonify({"session_id": session_id, "history": history})

```
