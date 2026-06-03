import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { ChatMessage } from '../types/chat';
import { getChatHistory, saveChatMessage } from '../api/chat';

interface ChatState {
  histories: Record<string, ChatMessage[]>;
  isOpen: boolean;
  isLoading: boolean;

  fetchHistory: (claimId: string) => Promise<void>;
  addMessage: (claimId: string, message: ChatMessage) => void;
  syncMessage: (claimId: string, message: ChatMessage) => Promise<void>;
  setLoading: (loading: boolean) => void;
  togglePanel: () => void;
  getHistory: (claimId: string) => ChatMessage[];
  clearHistory: (claimId: string) => void;
}

export const useChatStore = create<ChatState>()(
  persist(
    (set, get) => ({
      histories: {},
      isOpen: false,
      isLoading: false,

      fetchHistory: async (claimId) => {
        set({ isLoading: true });
        try {
          const data = await getChatHistory(claimId);
          set((state) => ({
            histories: {
              ...state.histories,
              [claimId]: data,
            },
          }));
        } catch (err) {
          console.error('Failed to load chat history:', err);
        } finally {
          set({ isLoading: false });
        }
      },

      addMessage: (claimId, message) =>
        set((state) => ({
          histories: {
            ...state.histories,
            [claimId]: [...(state.histories[claimId] || []), message],
          },
        })),

      syncMessage: async (claimId, message) => {
        try {
          await saveChatMessage(claimId, message);
        } catch (err) {
          console.error('Failed to sync chat message:', err);
        }
      },

      setLoading: (isLoading) => set({ isLoading }),

      togglePanel: () => set((state) => ({ isOpen: !state.isOpen })),

      getHistory: (claimId) => get().histories[claimId] || [],

      clearHistory: (claimId) =>
        set((state) => {
          const { [claimId]: _, ...rest } = state.histories;
          return { histories: rest };
        }),
    }),
    {
      name: 'claimauditai-chat',
      partialize: (state) => ({ histories: state.histories }),
    },
  ),
);
