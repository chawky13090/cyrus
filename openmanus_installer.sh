#!/bin/bash

set -e

log_info() { echo -e "[1;34m$1[0m"; }
log_warn() { echo -e "[1;33m$1[0m"; }
log_error() { echo -e "[1;31m$1[0m"; }

# Vérification des prérequis
if [ "$EUID" -eq 0 ]; then
    log_error "❌ Ne pas exécuter ce script en tant que root"
    exit 1
fi

log_info "📦 [1/15] Vérification et création du répertoire OpenManus..."
mkdir -p ~/OpenManus
cd ~/OpenManus

log_info "📦 [2/15] Installation des dépendances système..."
sudo apt update || log_warn "⚠️ apt update échoué"
sudo apt install -y nodejs npm python3 python3-venv python3-pip curl openssl build-essential || log_warn "⚠️ install partielle"

log_info "🐍 [3/15] Création de l'environnement Python..."
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate

log_info "📚 [4/15] Installation des dépendances Python..."
pip install --upgrade pip
pip install flask flask-cors chromadb requests || log_warn "⚠️ erreur pip"

log_info "🧠 [5/15] Installation propre d'Ollama..."
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
else
    log_info "Ollama déjà installé"
fi

log_info "🔄 [6/15] Démarrage du service Ollama..."
# Démarrer Ollama en arrière-plan s'il n'est pas déjà en cours d'exécution
if ! pgrep -x "ollama" > /dev/null; then
    nohup ollama serve > /dev/null 2>&1 &
    sleep 3
fi

log_info "🛠️ [7/15] PM2 global..."
sudo npm install -g pm2 || log_warn "⚠️ PM2 déjà installé"

log_info "🌐 [8/15] Configuration du frontend React..."
mkdir -p frontend/public frontend/src webui

cd frontend

log_info "📄 [9/15] Création de package.json..."
cat <<'EOF' > package.json
{
  "name": "openmanus-frontend",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "web-vitals": "^2.1.4"
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
EOF

log_info "🌐 [10/15] Installation des dépendances React..."
npm install

log_info "📁 [11/15] Création des fichiers React..."
cat <<'EOF' > public/index.html
<!DOCTYPE html>
<html lang="fr">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="OpenManus - Interface de chat IA" />
    <title>OpenManus</title>
    <style>
      body {
        margin: 0;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
          'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
          sans-serif;
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
        background-color: #f5f5f5;
      }
    </style>
  </head>
  <body>
    <noscript>Vous devez activer JavaScript pour utiliser cette application.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF

cat <<'EOF' > src/index.js
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

log_info "🧩 [12/15] Création de l'interface React..."
cat <<'EOF' > src/App.js
import React, { useEffect, useState } from 'react';

function App() {
  const [sessions, setSessions] = useState([]);
  const [chatId, setChatId] = useState('');
  const [data, setData] = useState([]);
  const [models, setModels] = useState([]);
  const [selectedModel, setSelectedModel] = useState('');
  const [currentModel, setCurrentModel] = useState('');
  const [message, setMessage] = useState('');
  const [response, setResponse] = useState('');
  const [loading, setLoading] = useState(false);
  const [uiError, setUiError] = useState(''); // For errors like loading models, sessions

  useEffect(() => {
    // Charger les modèles disponibles
    fetch('/api/models')
      .then(r => r.json())
      .then(data => {
        console.log("Modèles disponibles :", data);
        if (Array.isArray(data)) {
          setModels(data);
          setUiError(''); // Clear error on success
        } else {
          console.error("Erreur /api/models :", data);
          setModels([]);
          setUiError("Impossible de charger les modèles IA. Vérifiez la console pour les détails."); // Set UI error
        }
      })
      .catch(err => {
        console.error("Erreur réseau pour /api/models :", err);
        setModels([]);
        setUiError("Erreur réseau: Impossible de joindre /api/models."); // Set UI error
      });

    // Charger le modèle actuel
    fetch('/api/current_model')
      .then(r => r.json())
      .then(d => {
        setCurrentModel(d.model);
        setUiError(''); // Clear error on success
      })
      .catch(err => {
        console.error("Erreur current_model:", err);
        setUiError("Impossible de charger le modèle actuel."); // Set UI error
      });

    // Charger les sessions
    fetch('/api/sessions')
      .then(r => r.json())
      .then(data => {
        setSessions(data);
        setUiError(''); // Clear error on success
      })
      .catch(err => {
        console.error("Erreur sessions:", err);
        setUiError("Impossible de charger les sessions précédentes."); // Set UI error
      });
  }, []);

  useEffect(() => {
    if (chatId) {
      setUiError(''); // Clear previous error when chat ID changes
      fetch(`/api/memory/${chatId}`)
        .then(r => r.json())
        .then(data => {
          setData(data);
          // setUiError(''); // Clear error on success - might be too quick if other errors exist
        })
        .catch(err => {
          console.error("Erreur memory:", err);
          setData([]); // Clear data on error
          setUiError(`Impossible de charger l'historique pour la session ${chatId}.`); // Set UI error
        });
    }
  }, [chatId]);

  const handleChat = async () => {
    if (!message.trim() || !chatId) return;

    setLoading(true);
    setResponse(''); // Clear previous response/error
    setUiError('');   // Clear general UI errors
    try {
      const res = await fetch(`/api/chat/${chatId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message })
      });
      const result = await res.json();
      if (res.ok) {
        setResponse(result.response);
      } else {
        // Use 'response' state to display chat-specific errors
        setResponse(result.error || "Erreur inconnue du serveur de chat.");
      }
      setMessage('');

      // Recharger l'historique
      const memoryRes = await fetch(`/api/memory/${chatId}`);
      if (memoryRes.ok) { // Check if history fetch was ok
        const memoryData = await memoryRes.json();
        setData(memoryData);
      } else {
        // Don't overwrite chat response with memory error, but log and potentially set uiError
        console.error("Erreur rechargement historique:", await memoryRes.text());
        setUiError("Erreur lors du rechargement de l'historique du chat.");
      }
    } catch (err) {
      console.error("Erreur chat:", err);
      // Use 'response' state to display chat-specific errors
      setResponse("Erreur de communication avec le serveur de chat.");
    }
    setLoading(false);
  };

  const createNewChat = () => {
    const newId = `chat-${Date.now()}`;
    setChatId(newId);
    setSessions([...sessions, newId]);
    setData([]);
    setResponse('');
    setUiError(''); // Clear general UI errors
  };

  const handleModelChange = async () => {
    if (!selectedModel) return;
    setUiError(''); // Clear general UI errors
    try {
      const res = await fetch('/api/set_model', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: selectedModel })
      });
      if (res.ok) {
        setCurrentModel(selectedModel);
      } else {
        const errorData = await res.json();
        setUiError(errorData.error || "Erreur lors du changement de modèle.");
      }
    } catch (err) {
      console.error("Erreur changement modèle:", err);
      setUiError("Erreur réseau lors du changement de modèle.");
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && e.ctrlKey) {
      handleChat();
    }
  };

  return (
    <div style={{ 
      maxWidth: '1200px', 
      margin: '0 auto', 
      padding: '20px',
      fontFamily: 'Arial, sans-serif'
    }}>
      <h1 style={{ color: '#333', textAlign: 'center' }}>
        🤖 OpenManus - Interface de Chat IA
      </h1>

      {/* Display general UI errors here */}
      {uiError && (
        <div style={{ 
          backgroundColor: '#ffebee', // Light red background
          color: '#c62828', // Darker red text
          padding: '10px', 
          borderRadius: '4px', 
          marginBottom: '15px',
          textAlign: 'center',
          border: '1px solid #c62828' // Add a border for better visibility
        }}>
          <strong>Erreur:</strong> {uiError}
          <button 
            onClick={() => setUiError('')} 
            style={{ 
              marginLeft: '15px', 
              cursor: 'pointer', 
              backgroundColor: 'transparent', 
              border: '1px solid #c62828', 
              color: '#c62828',
              borderRadius: '4px',
              padding: '2px 8px'
            }}
          >
            Fermer
          </button>
        </div>
      )}

      <div style={{ 
        backgroundColor: 'white', 
        padding: '15px', 
        borderRadius: '8px', 
        marginBottom: '20px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
      }}>
        <div style={{ marginBottom: '15px' }}>
          <strong>Modèle IA actif :</strong> 
          <span style={{ color: '#007bff' }}> {currentModel || 'Aucun'}</span>
        </div>
        <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
          <select 
            value={selectedModel} 
            onChange={e => setSelectedModel(e.target.value)}
            style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
          >
            <option value="">-- Choisir un modèle --</option>
            {models.map(m => <option key={m} value={m}>{m}</option>)}
          </select>
          <button 
            onClick={handleModelChange}
            style={{ 
              padding: '8px 16px', 
              backgroundColor: '#007bff', 
              color: 'white', 
              border: 'none', 
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            Appliquer
          </button>
        </div>
      </div>

      <div style={{ 
        backgroundColor: 'white', 
        padding: '15px', 
        borderRadius: '8px', 
        marginBottom: '20px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
      }}>
        <div style={{ marginBottom: '15px' }}>
          <strong>Sessions de chat :</strong>
        </div>
        <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
          <select 
            value={chatId} 
            onChange={e => setChatId(e.target.value)}
            style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd', flex: 1 }}
          >
            <option value="">-- Choisir une session --</option>
            {sessions.map(s => <option key={s} value={s}>{s}</option>)}
          </select>
          <button 
            onClick={createNewChat}
            style={{ 
              padding: '8px 16px', 
              backgroundColor: '#28a745', 
              color: 'white', 
              border: 'none', 
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            ➕ Nouvelle session
          </button>
        </div>
      </div>

      {chatId && (
        <div style={{ 
          backgroundColor: 'white', 
          padding: '20px', 
          borderRadius: '8px',
          boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
        }}>
          <div style={{ marginBottom: '20px' }}>
            <textarea 
              value={message} 
              onChange={e => setMessage(e.target.value)}
              onKeyPress={handleKeyPress}
              rows={4} 
              placeholder="Posez votre question... (Ctrl+Entrée pour envoyer)"
              style={{ 
                width: '100%', 
                padding: '12px', 
                borderRadius: '4px', 
                border: '1px solid #ddd',
                fontSize: '14px',
                resize: 'vertical'
              }}
            />
            <button 
              onClick={handleChat}
              disabled={loading || !message.trim()}
              style={{ 
                marginTop: '10px',
                padding: '10px 20px', 
                backgroundColor: loading ? '#6c757d' : '#007bff', 
                color: 'white', 
                border: 'none', 
                borderRadius: '4px',
                cursor: loading ? 'not-allowed' : 'pointer',
                fontSize: '16px'
              }}
            >
              {loading ? '⏳ Envoi...' : '📤 Envoyer'}
            </button>
          </div>

          {response && (
            <div style={{ 
              backgroundColor: '#f8f9fa', 
              padding: '15px', 
              borderRadius: '4px', 
              marginBottom: '20px' 
            }}>
              <strong>Réponse :</strong>
              <div style={{ marginTop: '8px', whiteSpace: 'pre-wrap' }}>
                {response}
              </div>
            </div>
          )}

          <div>
            <h3 style={{ color: '#333' }}>📜 Historique de la conversation</h3>
            <div style={{ 
              maxHeight: '400px', 
              overflowY: 'auto', 
              border: '1px solid #ddd', 
              borderRadius: '4px',
              backgroundColor: '#fafafa'
            }}>
              {data.length === 0 ? (
                <p style={{ padding: '20px', textAlign: 'center', color: '#666' }}>
                  Aucun message dans cette session
                </p>
              ) : (
                <ul style={{ listStyle: 'none', padding: '0', margin: '0' }}>
                  {data.map(e => (
                    <li 
                      key={e.id} 
                      style={{ 
                        padding: '12px', 
                        borderBottom: '1px solid #eee',
                        backgroundColor: e.key === 'question' ? '#e3f2fd' : '#f3e5f5'
                      }}
                    >
                      <strong style={{ 
                        color: e.key === 'question' ? '#1976d2' : '#7b1fa2' 
                      }}>
                        {e.key === 'question' ? '❓' : '🤖'} {e.key}:
                      </strong>
                      <div style={{ marginTop: '5px', whiteSpace: 'pre-wrap' }}>
                        {e.value}
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
EOF

log_info "🧠 [13/15] Création du backend Flask..."
cd ../webui

cat <<'EOF' > app.py
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import subprocess
import chromadb
import requests
import uuid
import os
import json
import time

app = Flask(__name__, static_folder="../frontend/build", static_url_path="/")
CORS(app)

# Configuration ChromaDB
try:
    # Path for persistent storage, relative to webui/app.py location
    # This will create/use ~/OpenManus/chroma_db_openmanus/
    chroma_db_path = "../chroma_db_openmanus" 
    chroma_client = chromadb.PersistentClient(path=chroma_db_path) # <-- Changed this line
    chroma_collection = chroma_client.get_or_create_collection(name="openmanus-memory")
    print(f"✅ ChromaDB initialisé avec succès (persistent à: {chroma_db_path})") # Optional: updated print
except Exception as e:
    print(f"❌ Erreur ChromaDB: {e}")
    chroma_client = None
    chroma_collection = None

# Modèle par défaut
current_model = {"name": "llama2:latest"}

@app.route('/api/sessions', methods=['GET'])
def get_sessions():
    try:
        if not chroma_collection:
            return jsonify([])

        results = chroma_collection.get(include=['metadatas'])
        sessions = set()
        for meta in results['metadatas']:
            if 'chat_id' in meta:
                sessions.add(meta['chat_id'])
        return jsonify(sorted(list(sessions)))
    except Exception as e:
        print(f"Erreur get_sessions: {e}")
        return jsonify([])

@app.route('/api/memory/<chat_id>', methods=['GET'])
def get_memory(chat_id):
    try:
        if not chroma_collection:
            return jsonify([])

        results = chroma_collection.get(include=['documents', 'metadatas', 'ids'])
        memory = []
        for i in range(len(results['ids'])):
            if results['metadatas'][i].get('chat_id') == chat_id:
                memory.append({
                    'id': results['ids'][i],
                    'key': results['metadatas'][i].get('key', ''),
                    'value': results['documents'][i]
                })

        # Trier par ordre chronologique (basé sur l'ID qui contient un timestamp)
        memory.sort(key=lambda x: x['id'])
        return jsonify(memory[-50:])  # max 50 derniers messages
    except Exception as e:
        print(f"Erreur get_memory: {e}")
        return jsonify([])

@app.route('/api/chat/<chat_id>', methods=['POST'])
def chat(chat_id):
    try:
        message = request.json.get("message")
        if not message:
            return jsonify({"error": "Message vide"}), 400

        # Vérifier si Ollama est disponible
        try:
            requests.get("http://localhost:11434/api/tags", timeout=5)
        except:
            return jsonify({"error": "Ollama n'est pas disponible. Assurez-vous qu'il est démarré."}), 500

        # Envoyer la requête à Ollama
        response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": current_model["name"], 
                "prompt": message, 
                "stream": False
            },
            timeout=60
        )

        if response.status_code != 200:
            return jsonify({"error": f"Erreur Ollama: {response.status_code}"}), 500

        content = response.json().get("response", "")

        # Sauvegarder dans ChromaDB si disponible
        if chroma_collection:
            timestamp = int(time.time() * 1000)  # timestamp en millisecondes

            chroma_collection.add(
                documents=[message],
                metadatas=[{"key": "question", "chat_id": chat_id, "timestamp": timestamp}],
                ids=[f"q-{timestamp}-{str(uuid.uuid4())[:8]}"]
            )
            chroma_collection.add(
                documents=[content],
                metadatas=[{"key": "réponse", "chat_id": chat_id, "timestamp": timestamp + 1}],
                ids=[f"r-{timestamp + 1}-{str(uuid.uuid4())[:8]}"]
            )

        return jsonify({"response": content})
    except requests.exceptions.Timeout:
        return jsonify({"error": "Timeout - la requête a pris trop de temps"}), 500
    except Exception as e:
        print(f"Erreur chat: {e}")
        return jsonify({"error": f"Erreur serveur: {str(e)}"}), 500

@app.route('/api/models')
def list_models():
    try:
        # Essayer différents chemins pour ollama
        ollama_paths = ["/usr/local/bin/ollama", "/usr/bin/ollama", "ollama"]

        for path in ollama_paths:
            try:
                output = subprocess.check_output([path, "list"], text=True, timeout=10)
                lines = output.splitlines()
                models = []
                for line in lines:
                    if line.startswith("NAME") or not line.strip():
                        continue
                    parts = line.strip().split()
                    if parts:
                        models.append(parts[0])
                return jsonify(models)
            except (subprocess.CalledProcessError, FileNotFoundError):
                continue

        # Si aucun chemin ne fonctionne, essayer via l'API
        try:
            response = requests.get("http://localhost:11434/api/tags", timeout=5)
            if response.status_code == 200:
                data = response.json()
                models = [model['name'] for model in data.get('models', [])]
                return jsonify(models)
        except:
            pass

        return jsonify({"error": "Ollama non disponible"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/current_model')
def current():
    return jsonify({"model": current_model["name"]})

@app.route('/api/set_model', methods=["POST"])
def set_model():
    try:
        model = request.json.get("model")
        if not model:
            return jsonify({"error": "Missing model"}), 400
        current_model["name"] = model
        return jsonify({"message": f"Modèle changé pour {model}"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve_frontend(path):
    if path != "" and os.path.exists(os.path.join(app.static_folder, path)):
        return send_from_directory(app.static_folder, path)
    else:
        return send_from_directory(app.static_folder, 'index.html')

@app.route('/health')
def health():
    return jsonify({"status": "ok", "model": current_model["name"]})

if __name__ == '__main__':
    print("🚀 Démarrage d'OpenManus...")
    print(f"📁 Dossier statique: {app.static_folder}")
    print(f"🤖 Modèle par défaut: {current_model['name']}")

    # Vérifier si le build existe
    if not os.path.exists(app.static_folder):
        print("⚠️ Le dossier build n'existe pas. Exécutez d'abord le build React.")

    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

cd ..

log_info "🏗️ [14/15] Build du frontend React..."
cd frontend
npm run build || log_warn "⚠️ build frontend échoué"
cd ..

log_info "🧹 [15/15] Configuration et démarrage des services..."

# Créer un script de démarrage
cat <<'EOF' > start.sh
#!/bin/bash
cd ~/OpenManus

# Activer l'environnement Python
source .venv/bin/activate

# Démarrer Ollama si pas déjà en cours
if ! pgrep -x "ollama" > /dev/null; then
    echo "Démarrage d'Ollama..."
    nohup ollama serve > ollama.log 2>&1 &
    sleep 3
fi

# Télécharger un modèle par défaut si aucun n'existe
if [ -z "$(ollama list | grep -v NAME)" ]; then
    echo "Téléchargement du modèle llama2..."
    ollama pull llama2
fi

# Démarrer l'application Flask avec PM2
echo "Démarrage d'OpenManus (backend via PM2) sur http://localhost:5000"
# Ensure CWD is OpenManus for pm2, and script path is relative to CWD
# Correcting the pm2 start command:
# The script 'app.py' is inside 'webui', so pm2 needs to know that.
# We can either cd into webui first, or specify cwd for pm2.
# Option: Specify cwd for pm2 and full path to script or relative from APP_DIR
# Current directory for start.sh is ~/OpenManus

# pm2 start webui/app.py --name openmanus-backend --interpreter python3 -- P 5000 -- 
# The --P 5000 passes the port to the app.py script if it can receive it.
# app.py uses app.run(port=5000), so this might not be needed unless app.py is changed
# For simplicity, relying on app.py's hardcoded port 5000 for now.
# A better way for pm2 is to use an ecosystem file or ensure app.py takes port from ENV.
# For now, let's use:
# pm2 start webui/app.py --name openmanus-backend --interpreter python3 -- --port 5000

# If app.py is not modified to accept --port argument, the above won't work to set port.
# Given app.py: app.run(host='0.0.0.0', port=5000, debug=False)
# PM2 will run it, and it will bind to 5000.
# So, a simpler PM2 command is needed if app.py isn't changed:

# pm2 start webui/app.py --name openmanus-backend --interpreter python3

# Let's ensure logs are also handled by PM2 by default.
# To make it more robust and ensure it's served on 0.0.0.0:5000 as app.py defines
# The script path for PM2 should be relative to the CWD where PM2 is run or an absolute path.
# start.sh does `cd ~/OpenManus`.
# So, `webui/app.py` is the correct path for PM2 from `~/OpenManus`.

# Check if already running
pm2 describe openmanus-backend > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "OpenManus backend is already running via PM2."
  pm2 restart openmanus-backend
else
  echo "Démarrage d'OpenManus backend via PM2..."
  # The app.py is in webui, so pm2 should run from APP_DIR with script path webui/app.py
  pm2 start webui/app.py --name openmanus-backend --interpreter python3 
fi
pm2 save # Save the PM2 process list
echo "Pour voir les logs du backend: pm2 logs openmanus-backend"
echo "L'interface sera disponible sur : http://localhost:5000 (si le backend démarre correctement)"
EOF

chmod +x start.sh

# Créer un script d'arrêt
cat <<'EOF' > stop.sh
#!/bin/bash
echo "Arrêt des services OpenManus..."
echo "Arrêt du backend OpenManus (PM2)..."
pm2 stop openmanus-backend || echo "Backend PM2 process not found or already stopped."
pm2 delete openmanus-backend || echo "Backend PM2 process not found."
pm2 save # Save the PM2 process list (empty if deleted)
pkill -f "ollama serve"
echo "Services arrêtés."
EOF

chmod +x stop.sh

log_info "✅ Installation terminée !"
echo ""
echo "🚀 Pour démarrer OpenManus :"
echo "   cd ~/OpenManus && ./start.sh"
echo ""
echo "🛑 Pour arrêter OpenManus :"
echo "   cd ~/OpenManus && ./stop.sh"
echo ""
echo "🌐 L'interface sera disponible sur : http://localhost:5000"
echo ""
echo "📝 Logs d'Ollama : ~/OpenManus/ollama.log"

# Test de connectivité
log_info "🔍 Test de l'installation..."
if command -v ollama &> /dev/null; then
    log_info "✅ Ollama installé"
else
    log_warn "⚠️ Ollama non trouvé dans le PATH"
fi

if [ -f "frontend/build/index.html" ]; then
    log_info "✅ Build React créé"
else
    log_warn "⚠️ Build React manquant"
fi

log_info "🎉 OpenManus est prêt à être utilisé !"
```
