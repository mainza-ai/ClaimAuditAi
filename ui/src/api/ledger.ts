import { apiClient } from './client';
import type { LedgerEntry } from '../types/claim';

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  limit: number;
  offset: number;
}

export const getLedger = (limit = 50, offset = 0) =>
  apiClient.get<PaginatedResponse<LedgerEntry>>('/ledger', { params: { limit, offset } }).then((r) => r.data);
