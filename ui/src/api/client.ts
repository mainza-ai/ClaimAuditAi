import axios from 'axios';

export const apiClient = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 30000,
});

let accessToken: string | null = localStorage.getItem('claimauditai_token');
let refreshPromise: Promise<string | null> | null = null;

export function setAccessToken(token: string | null) {
  accessToken = token;
  if (token) {
    localStorage.setItem('claimauditai_token', token);
  } else {
    localStorage.removeItem('claimauditai_token');
  }
}

export function getAccessToken(): string | null {
  return accessToken;
}

apiClient.interceptors.request.use(
  (config) => {
    if (accessToken) {
      config.headers.Authorization = `Bearer ${accessToken}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

apiClient.interceptors.response.use(
  (response) => {
    const d = response.data;
    if (d && typeof d === 'object' && !Array.isArray(d) && (d.error || d.errors)) {
      const msg = d.error || (d.errors && d.errors[0]?.error) || 'Unknown server error';
      return Promise.reject(new Error(msg));
    }
    return response;
  },
  (error) => {
    if (error.response?.status === 401) {
      const requestUrl = error.config?.url || '';
      if (!requestUrl.includes('/auth/login') && !requestUrl.includes('/auth/introspect')) {
        setAccessToken(null);
        localStorage.removeItem('claimauditai_token');
        window.location.href = '/';
        return Promise.reject(new Error('Session expired. Please log in again.'));
      }
    }
    const d = error.response?.data;
    const msg = d?.error_description || d?.error || (d?.errors && d?.errors[0]?.error) || error.message || 'Network error';
    return Promise.reject(new Error(msg));
  },
);
