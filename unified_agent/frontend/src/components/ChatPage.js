import React, { useState, useEffect, useRef } from 'react';
import { postApi } from '../services/api'; // Assuming api.js is in src/services
import './ChatPage.css';

function ChatPage({ onLogout }) { // Added onLogout prop
  const [sessionId, setSessionId] = useState(`session_${Date.now()}`);
  const [message, setMessage] = useState('');
  const [chatHistory, setChatHistory] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(''); // For displaying API errors (chat related)

  const chatEndRef = useRef(null);

  // Nmap State
  const [nmapTarget, setNmapTarget] = useState('');
  const [nmapOptions, setNmapOptions] = useState('-T4 -F');
  const [nmapResult, setNmapResult] = useState(null);
  const [nmapLoading, setNmapLoading] = useState(false);
  const [nmapError, setNmapError] = useState('');

  // SSH State
  const [sshHostname, setSshHostname] = useState('');
  const [sshPort, setSshPort] = useState('22');
  const [sshUsername, setSshUsername] = useState('');
  const [sshPassword, setSshPassword] = useState('');
  const [sshCommand, setSshCommand] = useState('');
  const [sshResult, setSshResult] = useState(null);
  const [sshLoading, setSshLoading] = useState(false);
  const [sshError, setSshError] = useState('');

  const scrollToBottom = () => {
    chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  useEffect(scrollToBottom, [chatHistory]);
  
  // useEffect to load initial chat history if needed (or handled by session management)
  // For now, new session starts empty

  const handleNmapScan = async () => {
    setNmapLoading(true);
    setNmapError('');
    setNmapResult(null);
    try {
      const result = await postApi('/api/tools/nmap/scan', { target: nmapTarget, options: nmapOptions });
      setNmapResult(result);
    } catch (err) {
      console.error("Nmap API error:", err);
      const errorMsg = err.error || (typeof err === 'string' ? err : "Nmap scan failed.");
      setNmapError(errorMsg);
      if (err.status === 401) onLogout();
    } finally {
      setNmapLoading(false);
    }
  };

  const handleSshExecute = async () => {
    setSshLoading(true);
    setSshError('');
    setSshResult(null);
    try {
      const result = await postApi('/api/tools/ssh/execute', { 
        hostname: sshHostname, 
        port: parseInt(sshPort, 10), // Ensure port is an integer
        username: sshUsername, 
        password: sshPassword, 
        command: sshCommand 
      });
      setSshResult(result);
    } catch (err) {
      console.error("SSH API error:", err);
      const errorMsg = err.error || (typeof err === 'string' ? err : "SSH command execution failed.");
      setSshError(errorMsg);
      if (err.status === 401) onLogout();
    } finally {
      setSshLoading(false);
    }
  };

  const handleSendMessage = async () => {
    if (!message.trim()) return;
    const userMsg = { role: 'user', content: message, timestamp: new Date().toISOString() };
    setChatHistory(prev => [...prev, userMsg]);
    setMessage('');
    setIsLoading(true);
    setError('');

    try {
      const data = await postApi('/api/chat', { message: userMsg.content, session_id: sessionId });
      const aiMsg = { role: 'assistant', content: data.response || "No response", timestamp: new Date().toISOString() };
      setChatHistory(prev => [...prev, aiMsg]);
    } catch (err) {
      console.error("Chat API error:", err);
      // err might be an object like { error: message, status: code } from postApi
      const errorMsg = err.error || "Failed to send message. Please try again.";
      setError(errorMsg); // Display error in UI
      // Optionally add error to chat history
      setChatHistory(prev => [...prev, {role: 'system', content: `Error: ${errorMsg}`, timestamp: new Date().toISOString()}]);
      if (err.status === 401) { // If postApi specifically identified an auth error
        onLogout(); // Trigger logout if auth failed
      }
    } finally {
      setIsLoading(false);
    }
  };
  
  const handleNewSession = () => {
    setSessionId(`session_${Date.now()}`);
    setChatHistory([]);
    setError('');
    setMessage('');
  };

  return (
    <div className="chat-page">
      <header className="chat-header">
        <h3>Unified AI Agent Chat</h3>
        <div className="session-controls">
            <span>Session ID: {sessionId}</span>
            <button onClick={handleNewSession} className="new-session-btn">New Session</button>
            <button onClick={onLogout} className="logout-btn">Logout</button> 
        </div>
      </header>
      {error && <p className="chat-error">Error: {error}</p>}
      <div className="chat-history-container">
        {chatHistory.map((msg, index) => (
          <div key={index} className={`chat-message ${msg.role}`}>
            <span className="sender">{msg.role === 'user' ? 'You' : msg.role === 'assistant' ? 'Agent' : 'System'}: </span>
            <span className="content">{msg.content}</span>
          </div>
        ))}
        {isLoading && <div className="chat-message system">Agent is typing...</div>}
        <div ref={chatEndRef} />
      </div>
      <div className="chat-input-area">
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          onKeyPress={(e) => e.key === 'Enter' && !e.shiftKey && handleSendMessage()}
          placeholder="Type your message..."
          disabled={isLoading}
        />
        <button onClick={handleSendMessage} disabled={isLoading || !message.trim()}>
          {isLoading ? 'Sending...' : 'Send'}
        </button>
      </div>
      {/* NetOps Tools Area */}
      <div className="netops-tools-area">
        {/* Nmap Section */}
        <div className="netops-tool-section nmap-section">
          <h4>Nmap Scan</h4>
          <div className="tool-form">
            <input 
              type="text" 
              value={nmapTarget} 
              onChange={(e) => setNmapTarget(e.target.value)} 
              placeholder="Target (e.g., 192.168.1.1 or domain.com)"
            />
            <input 
              type="text" 
              value={nmapOptions} 
              onChange={(e) => setNmapOptions(e.target.value)} 
              placeholder="Nmap Options"
            />
            <button onClick={handleNmapScan} disabled={nmapLoading || !nmapTarget.trim()}>
              {nmapLoading ? 'Scanning...' : 'Run Nmap Scan'}
            </button>
          </div>
          {nmapLoading && <div className="tool-loading">Loading Nmap results...</div>}
          {nmapError && <div className="tool-error">Nmap Error: {nmapError}</div>}
          {nmapResult && (
            <div className="tool-result">
              <h5>Nmap Result:</h5>
              <pre>{JSON.stringify(nmapResult, null, 2)}</pre>
            </div>
          )}
        </div>

        {/* SSH Section */}
        <div className="netops-tool-section ssh-section">
          <h4>SSH Command Execution</h4>
          <div className="tool-form">
            <input 
              type="text" 
              value={sshHostname} 
              onChange={(e) => setSshHostname(e.target.value)} 
              placeholder="Hostname or IP"
            />
            <input 
              type="number" 
              value={sshPort} 
              onChange={(e) => setSshPort(e.target.value)} 
              placeholder="Port (default 22)"
            />
            <input 
              type="text" 
              value={sshUsername} 
              onChange={(e) => setSshUsername(e.target.value)} 
              placeholder="Username"
            />
            <input 
              type="password" 
              value={sshPassword} 
              onChange={(e) => setSshPassword(e.target.value)} 
              placeholder="Password (use with caution)"
            />
            <textarea 
              value={sshCommand} 
              onChange={(e) => setSshCommand(e.target.value)} 
              placeholder="Command to execute"
              rows={3}
            />
            <button onClick={handleSshExecute} disabled={sshLoading || !sshHostname.trim() || !sshUsername.trim() || !sshCommand.trim()}>
              {sshLoading ? 'Executing...' : 'Execute SSH Command'}
            </button>
          </div>
          {sshLoading && <div className="tool-loading">Executing SSH command...</div>}
          {sshError && <div className="tool-error">SSH Error: {sshError}</div>}
          {sshResult && (
            <div className="tool-result">
              <h5>SSH Result:</h5>
              <p><strong>Exit Status:</strong> {sshResult.exit_status}</p>
              {sshResult.stdout && <div><strong>Stdout:</strong><pre>{sshResult.stdout}</pre></div>}
              {sshResult.stderr && <div><strong>Stderr:</strong><pre>{sshResult.stderr}</pre></div>}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
export default ChatPage;
