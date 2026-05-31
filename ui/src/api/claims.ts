import { apiClient } from './client';
import type { HeldClaim, ClaimDetail } from '../types/claim';

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  limit: number;
  offset: number;
}

export const getHeldClaims = (limit = 50, offset = 0) =>
  apiClient.get<PaginatedResponse<HeldClaim>>('/claims/held', { params: { limit, offset } }).then((r) => r.data);

export const getClaimDetail = (id: string) =>
  apiClient.get<ClaimDetail>(`/claims/${id}`).then((r) => r.data);

export const approveClaim = (id: string, body: { authorizedBy: string; rationaleSummary: string }) =>
  apiClient.post(`/claims/${id}/approve`, body).then((r) => r.data);

export const escalateClaim = (id: string, body: { authorizedBy: string; rationaleSummary: string }) =>
  apiClient.post(`/claims/${id}/escalate`, body).then((r) => r.data);

export const rejectClaim = (id: string, body: { authorizedBy: string; rationaleSummary: string }) =>
  apiClient.post(`/claims/${id}/reject`, body).then((r) => r.data);

export const loadSampleData = () =>
  apiClient.post('/samples/load', {}, { timeout: 120000 }).then((r) => r.data);

export const getLedger = (limit = 50, offset = 0) =>
  apiClient.get<PaginatedResponse<import('../types/claim').LedgerEntry>>('/ledger', { params: { limit, offset } }).then((r) => r.data);
