import { apiClient } from './client';
import type { ChatMessage, ClaimContext } from '../types/chat';

export const sendChatMessage = (
  messages: ChatMessage[],
  claimContext: ClaimContext | null
) =>
  apiClient
    .post<{ response: string }>('/chat', {
      messages: messages.map(({ role, content }) => ({ role, content })),
      claimContext: claimContext ? JSON.stringify(claimContext) : null,
    })
    .then((r) => r.data.response);