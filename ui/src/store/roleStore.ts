import { create } from 'zustand';

export type UserRole = 'Auditor' | 'Director' | 'Specialist' | 'Tech Owner / Admin';

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
  activeRole: 'Auditor',
  userName: '',
  fhirUser: '',
  authRoles: [],
  setActiveRole: (role) => set({ activeRole: role }),
  setAuthContext: (name, fhirUser, roles) => set({ userName: name, fhirUser, authRoles: roles }),
  clearAuth: () => set({ userName: '', fhirUser: '', authRoles: [], activeRole: 'Auditor' }),
}));
