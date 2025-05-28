import React, { useState, useEffect } from 'react';
import LoginPage from './components/LoginPage';
import ChatPage from './components/ChatPage';
import { setAuthToken, clearAuthToken, getAuthHeaders } from './services/api';
import './App.css';

function App() {
  // Attempt to retrieve auth token from localStorage if implemented
  // const [isAuthenticated, setIsAuthenticated] = useState(!!localStorage.getItem('authToken'));
  const [isAuthenticated, setIsAuthenticated] = useState(false); // Start as not authenticated

  // This effect can be used to check if a stored token is still valid with an API call
  // For MVP, we'll rely on the first API call in ChatPage to validate.
  // useEffect(() => {
  //   const token = localStorage.getItem('authToken');
  //   if (token) {
  //     // Potentially make a /api/auth/verify endpoint call
  //     // For now, assume if token exists, user was previously logged in
  //     // setAuthToken directly from stored token if it's stored raw (not recommended for production)
  //     // This part needs careful thought for security if localStorage is used.
  //     // For now, basic auth doesn't store token in JS, browser handles it.
  //     // So, this state is more about "did the user attempt to login?"
  //   }
  // }, []);

  const handleLoginSuccess = (username, password) => {
    setAuthToken(username, password); // Store credentials for Basic Auth header
    setIsAuthenticated(true);
  };

  const handleLogout = () => {
    clearAuthToken();
    setIsAuthenticated(false);
  };

  return (
    <div className="App">
      {!isAuthenticated ? (
        <LoginPage onLoginSuccess={handleLoginSuccess} />
      ) : (
        <main className="App-main">
          <ChatPage onLogout={handleLogout} />
        </main>
      )}
    </div>
  );
}

export default App;
```
