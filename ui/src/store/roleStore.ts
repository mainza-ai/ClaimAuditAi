import { create } from 'zustand';

export type UserRole = 'Viewer' | 'Auditor' | 'Specialist' | 'Director' | 'Admin';

const ROLE_ORDER: UserRole[] = ['Viewer', 'Auditor', 'Specialist', 'Director', 'Admin'];

export function deriveActiveRole(roles: string[]): UserRole {
  let highestIdx = 0;
  for (const r of roles) {
    const idx = ROLE_ORDER.indexOf(r as UserRole);
    if (idx >= 0 && idx > highestIdx) {
      highestIdx = idx;
      if (idx === 4) break;
    }
  }
  return ROLE_ORDER[highestIdx];
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
