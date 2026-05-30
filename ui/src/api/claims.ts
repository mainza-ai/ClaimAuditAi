import { apiClient } from './client';
import type { HeldClaim, ClaimDetail } from '../types/claim';

export const getHeldClaims = () =>
  apiClient.get<HeldClaim[]>('/claims/held').then((r) => r.data);

export const getClaimDetail = (id: string) =>
  apiClient.get<ClaimDetail>(`/claims/${id}`).then((r) => r.data);

export const approveClaim = (id: string) =>
  apiClient.post(`/claims/${id}/approve`).then((r) => r.data);

export const escalateClaim = (id: string) =>
  apiClient.post(`/claims/${id}/escalate`).then((r) => r.data);

export const loadSampleData = () =>
  apiClient.post('/samples/load', {}, { timeout: 120000 }).then((r) => r.data);