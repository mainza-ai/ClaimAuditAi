import axios from 'axios';

export const apiClient = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Basic ' + btoa('_SYSTEM:SYS'),
  },
  timeout: 30000,
});

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
    const d = error.response?.data;
    const msg = d?.error || (d?.errors && d?.errors[0]?.error) || error.message || 'Network error';
    return Promise.reject(new Error(msg));
  },
);