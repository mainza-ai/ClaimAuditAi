const ROLE_LEVEL: Record<string, number> = {
  Viewer: 1, Auditor: 2, Specialist: 3, Director: 4, Admin: 5,
};

function level(role: string): number {
  return ROLE_LEVEL[role] ?? 0;
}

export const PERMISSIONS = {
  canApprove: (role: string) => level(role) >= 2,
  canEscalate: (role: string) => level(role) >= 2,
  canReject: (role: string) => level(role) >= 2,
  canReaudit: (role: string) => level(role) >= 2,
  canManageData: (role: string) => role === 'Admin',
} as const;
