import { create } from 'zustand';

export type UserRole = 'Auditor' | 'Director' | 'Specialist' | 'Tech Owner / Admin';

interface RoleState {
  activeRole: UserRole;
  setActiveRole: (role: UserRole) => void;
}

export const useRoleStore = create<RoleState>((set) => ({
  activeRole: 'Auditor',
  setActiveRole: (role) => set({ activeRole: role }),
}));
