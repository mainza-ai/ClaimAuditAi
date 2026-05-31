export const PERMISSIONS = {
  canApprove: (role: string) => role === 'Director' || role === 'Tech Owner / Admin',
  canEscalate: (role: string) => role === 'Auditor' || role === 'Director' || role === 'Tech Owner / Admin',
  canReject: (role: string) => role === 'Director' || role === 'Tech Owner / Admin',
  canRecommend: (role: string) => role === 'Auditor',
  canManageData: (role: string) => role === 'Tech Owner / Admin' || role === 'admin',
} as const;
