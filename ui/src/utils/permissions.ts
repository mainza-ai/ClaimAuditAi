export const PERMISSIONS = {
  canApprove: (role: string) => role === 'Director' || role === 'Admin',
  canEscalate: (role: string) => role === 'Auditor' || role === 'Specialist' || role === 'Director' || role === 'Admin',
  canReject: (role: string) => role === 'Director' || role === 'Admin',
  canManageData: (role: string) => role === 'Admin',
  canReaudit: (role: string) => role === 'Admin',
} as const;
