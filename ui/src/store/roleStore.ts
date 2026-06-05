import { create } from 'zustand';

export type UserRole = 'Viewer' | 'Auditor' | 'Specialist' | 'Director' | 'Admin';

const ROLE_LEVEL: Record<string, number> = {
  Viewer: 1,
  Auditor: 2,
  Specialist: 3,
  Director: 4,
  Admin: 5,
  '%All': 5,
};

export function deriveActiveRole(roles: string[]): UserRole {
  let highest: UserRole = 'Viewer';
  let highestLevel = 0;
  for (const r of roles) {
    const level = ROLE_LEVEL[r] || 0;
    if (level >= 5) return 'Admin';
    if (level === 4 && highestLevel < 4) {
      highest = 'Director';
      highestLevel = 4;
    }
    if (level === 3 && highestLevel < 3) {
      highest = 'Specialist';
      highestLevel = 3;
    }
    if (level === 2 && highestLevel < 2) {
      highest = 'Auditor';
      highestLevel = 2;
    }
    if (level === 1 && highestLevel < 1) {
      highest = 'Viewer';
      highestLevel = 1;
    }
  }
  return highest;
}

interface RoleState {
  activeRole: UserRole;
  userName: string;
  fhirUser: string;
  authRoles: string[];
  setActiveRole: (role: UserRole) => void;
  setAuthContext: (name: string, fhirUser: string, roles: string[]) => void;
  clearAuth: () => void;
}

export const useRoleStore = create<RoleState>((set) => ({
  activeRole: 'Viewer',
  userName: '',
  fhirUser: '',
  authRoles: [],
  setActiveRole: (role) => set({ activeRole: role }),
  setAuthContext: (name, fhirUser, roles) =>
    set({
      userName: name,
      fhirUser,
      authRoles: roles,
      activeRole: deriveActiveRole(roles),
    }),
  clearAuth: () => set({ userName: '', fhirUser: '', authRoles: [], activeRole: 'Auditor' }),
}));
