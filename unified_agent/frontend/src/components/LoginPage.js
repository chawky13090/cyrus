import React, { useState } from 'react';
import './LoginPage.css';

function LoginPage({ onLoginSuccess }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(''); // Clear previous errors

    // Basic validation
    if (!username || !password) {
      setError('Username and password are required.');
      return;
    }
    
    // In a real app, you'd call an API to verify credentials.
    // For Basic Auth, we just store the token and let the browser send it.
    // The first API call made by ChatPage will test the credentials.
    // If it fails with 401, App.js will clear the token and show LoginPage.
    onLoginSuccess(username, password); 
  };

  return (
    <div className="login-page">
      <form onSubmit={handleSubmit} className="login-form">
        <h2>Agent Login</h2>
        {error && <p className="login-error">{error}</p>}
        <div className="form-group">
          <label htmlFor="username">Username</label>
          <input
            type="text"
            id="username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
          />
        </div>
        <div className="form-group">
          <label htmlFor="password">Password</label>
          <input
            type="password"
            id="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>
        <button type="submit" className="login-button">Login</button>
      </form>
    </div>
  );
}
export default LoginPage;
