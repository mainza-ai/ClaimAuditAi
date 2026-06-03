import { apiClient, getAccessToken } from './client';
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

export async function* streamChatMessage(
  messages: ChatMessage[],
  claimContext: ClaimContext | null,
): AsyncGenerator<string> {
  const token = getAccessToken();
  const response = await fetch('/api/chat/stream', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({
      messages: messages.map(({ role, content }) => ({ role, content })),
      claimContext: claimContext ? JSON.stringify(claimContext) : null,
    }),
  });

  if (!response.ok) {
    throw new Error(`Stream error: ${response.status} ${response.statusText}`);
  }

  const reader = response.body?.getReader();
  if (!reader) throw new Error('ReadableStream not supported');

  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() || '';

    for (const line of lines) {
      if (line.startsWith('data: ')) {
        const data = line.slice(6).trim();
        if (data === '[DONE]') return;
        if (data) yield data;
      }
    }
  }
}

export const getChatHistory = (claimId: string) =>
  apiClient
    .get<ChatMessage[]>(`/chat/history/${claimId}`)
    .then((r) => r.data);

export const saveChatMessage = (claimId: string, message: ChatMessage) =>
  apiClient
    .post(`/chat/history/${claimId}`, message)
    .then((r) => r.data);
