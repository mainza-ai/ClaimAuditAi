import axios from 'axios';

export const apiClient = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Basic ' + btoa('_SYSTEM:SYS'),
  },
  timeout: 30000,
});