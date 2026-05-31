import { apiClient } from './client';
import type { HeldClaim, ClaimDetail } from '../types/claim';

export const getHeldClaims = () =>
  apiClient.get<HeldClaim[]>('/claims/held').then((r) => Array.isArray(r.data) ? r.data : []);

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
