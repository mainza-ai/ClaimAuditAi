import { apiClient } from './client';
import type { LedgerEntry } from '../types/claim';

export const getLedger = () =>
apiClient.get<LedgerEntry[]>('/ledger').then((r) => r.data);
