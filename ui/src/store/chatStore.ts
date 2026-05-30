import { create } from 'zustand';
import type { ChatMessage } from '../types/chat';

interface ChatState {
  histories: Record<string, ChatMessage[]>;
  activeClaimId: string | null;
  isOpen: boolean;
  isLoading: boolean;

  setActiveClaim: (claimId: string) => void;
  addMessage: (claimId: string, message: ChatMessage) => void;
  setLoading: (loading: boolean) => void;
  togglePanel: () => void;
  getHistory: (claimId: string) => ChatMessage[];
  clearHistory: (claimId: string) => void;
}

export const useChatStore = create<ChatState>((set, get) => ({
  histories: {},
  activeClaimId: null,
  isOpen: false,
  isLoading: false,

  setActiveClaim: (claimId) => set({ activeClaimId: claimId }),

  addMessage: (claimId, message) =>
    set((state) => ({
      histories: {
        ...state.histories,
        [claimId]: [...(state.histories[claimId] || []), message],
      },
    })),

  setLoading: (isLoading) => set({ isLoading }),

  togglePanel: () => set((state) => ({ isOpen: !state.isOpen })),

  getHistory: (claimId) => get().histories[claimId] || [],

  clearHistory: (claimId) =>
    set((state) => {
      const { [claimId]: _, ...rest } = state.histories;
      return { histories: rest };
    }),
}));