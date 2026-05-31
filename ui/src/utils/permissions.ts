export const PERMISSIONS = {
  canApprove: (role: string) => role === 'Director' || role === 'Tech Owner / Admin',
  canEscalate: (role: string) => role === 'Auditor' || role === 'Specialist' || role === 'Director' || role === 'Tech Owner / Admin',
  canReject: (role: string) => role === 'Director' || role === 'Tech Owner / Admin',
  canManageData: (role: string) => role === 'Tech Owner / Admin',
} as const;
