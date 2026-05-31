import { apiClient } from './client';
import type { SystemStats, TrendDay } from '../types/claim';

export const getStats = (days = 30) =>
  apiClient.get<SystemStats>('/stats', { params: { days } }).then((r) => r.data);

export const getTrends = () =>
  apiClient.get<TrendDay[]>('/stats/trends').then((r) => Array.isArray(r.data) ? r.data : []);
