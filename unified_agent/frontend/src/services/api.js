// Basic API service
// Stores auth token (username:password encoded in base64)

let authToken = null;

export function setAuthToken(username, password) {
  authToken = btoa(`${username}:${password}`); // Base64 encode
  // Optionally store in localStorage if persistence across sessions is needed (and secure)
  // localStorage.setItem('authToken', authToken); 
}

export function clearAuthToken() {
  authToken = null;
  // localStorage.removeItem('authToken');
}

export function getAuthHeaders() {
  if (!authToken) return {};
  return { 'Authorization': `Basic ${authToken}` };
}

// Example of a GET request
// export async function fetchChatHistory(sessionId) {
//   const response = await fetch(`/api/chat/history/${sessionId}`, {
//     method: 'GET',
//     headers: {
//       ...getAuthHeaders(),
//       'Content-Type': 'application/json'
//     }
//   });
//   if (!response.ok) {
//     if (response.status === 401) clearAuthToken(); // Clear token on auth failure
//     // Handle errors as in App.js or throw
//     throw new Error(`API error: ${response.status}`);
//   }
//   return response.json();
// }

// POST request helper (can be used by chat, tools)
export async function postApi(endpoint, body) {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      ...getAuthHeaders(),
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(body)
  });

  if (response.status === 401) { // Unauthorized
    clearAuthToken(); // Clear token, triggers logout flow in App.js
    // Optionally, you could throw a specific error or return a specific structure
    // to inform the caller that it was an auth error.
    const errorData = { error: "Authentication failed. Please login again.", status: 401 };
    throw errorData; // Throw an object or a custom Error
  }
  
  // Try to parse JSON regardless of ok status, backend might send error details
  const data = await response.json();

  if (!response.ok) {
    // Use error from JSON if available, otherwise statusText
    const message = data.error || response.statusText || `HTTP error ${response.status}`;
    const errorData = { error: message, status: response.status, data: data };
    throw errorData;
  }
  return data;
}
