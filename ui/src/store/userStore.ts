import { create } from 'zustand';
import { persist } from 'zustand/middleware';

type UserRole = 'auditor' | 'director' | 'admin';

interface UserState {
  name: string;
  role: UserRole;
  setUser: (name: string, role: UserRole) => void;
}

export const useUserStore = create<UserState>()(
  persist(
    (set) => ({
      name: '',
      role: 'auditor',
      setUser: (name, role) => set({ name, role }),
    }),
    { name: 'claimauditai-user' }
  )
);
