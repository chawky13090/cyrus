import chromadb
import logging
import time
import os

logger = logging.getLogger(__name__)

def initialize_chromadb(db_path, collection_name="unified_agent_conversations"):
    try:
        if not os.path.exists(db_path):
            os.makedirs(db_path, exist_ok=True)
            logger.info(f"Created ChromaDB directory: {db_path}")

        client = chromadb.PersistentClient(path=db_path)
        collection = client.get_or_create_collection(
            name=collection_name,
            metadata={"hnsw:space": "cosine"} # Example metadata, adjust as needed
        )
        logger.info(f"ChromaDB collection '{collection_name}' loaded/created at path: {db_path}")
        return collection
    except Exception as e:
        logger.error(f"Error initializing ChromaDB at {db_path} with collection {collection_name}: {e}", exc_info=True)
        return None

def store_conversation(collection, session_id: str, user_message: str, ai_response: str, model_used: str):
    if collection is None:
        logger.warning("ChromaDB collection not available. Cannot store conversation.")
        return False
    try:
        timestamp = int(time.time() * 1000)
        # Store user message
        collection.add(
            ids=[f"user_{session_id}_{timestamp}"],
            documents=[user_message],
            metadatas=[{
                "session_id": session_id, 
                "role": "user", 
                "timestamp": timestamp,
                "model_used": "N/A"
            }]
        )
        # Store AI response
        collection.add(
            ids=[f"ai_{session_id}_{timestamp+1}"], # ensure unique id and order
            documents=[ai_response],
            metadatas=[{
                "session_id": session_id, 
                "role": "assistant", 
                "timestamp": timestamp + 1,
                "model_used": model_used
            }]
        )
        logger.info(f"Conversation part stored for session {session_id}")
        return True
    except Exception as e:
        logger.error(f"Error storing conversation to ChromaDB for session {session_id}: {e}", exc_info=True)
        return False

def get_conversation_history(collection, session_id: str, limit: int = 20):
    if collection is None:
        logger.warning("ChromaDB collection not available. Cannot retrieve conversation history.")
        return []
    try:
        results = collection.get(
            where={"session_id": session_id},
            include=["documents", "metadatas"],
            # No simple sort_by_timestamp in basic get, so retrieve more and sort in Python
            # A higher limit might be needed if many sessions share IDs (not typical)
        )
        
        history = []
        if results and results['ids']:
            for i in range(len(results['ids'])):
                history.append({
                    "id": results['ids'][i],
                    "message": results['documents'][i],
                    "metadata": results['metadatas'][i]
                })
        
        # Sort by timestamp
        history.sort(key=lambda x: x['metadata'].get('timestamp', 0))
        
        return history[-limit:] # Return last 'limit' messages
    except Exception as e:
        logger.error(f"Error retrieving conversation history for session {session_id}: {e}", exc_info=True)
        return []

```
