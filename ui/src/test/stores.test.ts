import { describe, it, expect, beforeEach } from 'vitest';
import { useRoleStore } from '../store/roleStore';
import { useChatStore } from '../store/chatStore';

describe('useRoleStore', () => {
  beforeEach(() => {
    useRoleStore.getState().clearAuth();
  });

  it('should have initial state', () => {
    const state = useRoleStore.getState();
    expect(state.activeRole).toBe('Auditor');
    expect(state.userName).toBe('');
    expect(state.fhirUser).toBe('');
    expect(state.authRoles).toEqual([]);
  });

  it('should set authentication context correctly', () => {
    useRoleStore.getState().setAuthContext('Dr. House', 'Practitioner/house', ['Auditor', 'Admin']);
    const state = useRoleStore.getState();
    expect(state.userName).toBe('Dr. House');
    expect(state.fhirUser).toBe('Practitioner/house');
    expect(state.authRoles).toEqual(['Auditor', 'Admin']);
  });

  it('should set active role correctly', () => {
    useRoleStore.getState().setActiveRole('Director');
    const state = useRoleStore.getState();
    expect(state.activeRole).toBe('Director');
  });

  it('should clear authentication state on logout', () => {
    useRoleStore.getState().setAuthContext('Dr. House', 'Practitioner/house', ['Auditor']);
    useRoleStore.getState().setActiveRole('Specialist');
    useRoleStore.getState().clearAuth();

    const state = useRoleStore.getState();
    expect(state.userName).toBe('');
    expect(state.fhirUser).toBe('');
    expect(state.authRoles).toEqual([]);
    expect(state.activeRole).toBe('Auditor');
  });
});

describe('useChatStore', () => {
  beforeEach(() => {
    useChatStore.getState().clearHistory('claim-123');
  });

  it('should have empty initial history', () => {
    const history = useChatStore.getState().getHistory('claim-123');
    expect(history).toEqual([]);
  });

  it('should add messages to history', () => {
    useChatStore
      .getState()
      .addMessage('claim-123', { role: 'user', content: 'hello', timestamp: '2026-06-03T00:00:00.000Z' });
    let history = useChatStore.getState().getHistory('claim-123');
    expect(history).toHaveLength(1);
    expect(history[0]).toEqual({ role: 'user', content: 'hello', timestamp: '2026-06-03T00:00:00.000Z' });

    useChatStore
      .getState()
      .addMessage('claim-123', { role: 'assistant', content: 'hi there', timestamp: '2026-06-03T00:00:01.000Z' });
    history = useChatStore.getState().getHistory('claim-123');
    expect(history).toHaveLength(2);
    expect(history[1].content).toBe('hi there');
  });

  it('should clear history correctly', () => {
    useChatStore
      .getState()
      .addMessage('claim-123', { role: 'user', content: 'hello', timestamp: '2026-06-03T00:00:00.000Z' });
    useChatStore.getState().clearHistory('claim-123');
    const history = useChatStore.getState().getHistory('claim-123');
    expect(history).toEqual([]);
  });
});
