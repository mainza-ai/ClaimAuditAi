import React from 'react';
import { describe, it, expect } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { LoginPage } from '../views/LoginPage';

function renderWithProviders(ui: React.ReactElement) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <MemoryRouter>{ui}</MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('LoginPage', () => {
  it('renders login form', () => {
    renderWithProviders(<LoginPage />);
    expect(screen.getByText('ClaimAuditAI')).toBeInTheDocument();
    expect(screen.getByText('SMART on FHIR Authentication')).toBeInTheDocument();
  });

  it('has username and password inputs', () => {
    renderWithProviders(<LoginPage />);
    expect(screen.getByLabelText('Username')).toBeInTheDocument();
    expect(screen.getByLabelText('Password')).toBeInTheDocument();
  });

  it('has a submit button', () => {
    renderWithProviders(<LoginPage />);
    expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument();
  });

  it('submit button is disabled when fields are empty', () => {
    renderWithProviders(<LoginPage />);
    const button = screen.getByRole('button', { name: /sign in/i });
    expect(button).toBeDisabled();
  });

  it('shows error on failed login attempt', async () => {
    renderWithProviders(<LoginPage />);
    const usernameInput = screen.getByLabelText('Username');
    const passwordInput = screen.getByLabelText('Password');
    fireEvent.change(usernameInput, { target: { value: 'wrong' } });
    fireEvent.change(passwordInput, { target: { value: 'wrong' } });
    // Submit should trigger API call which will fail
    fireEvent.click(screen.getByRole('button', { name: /sign in/i }));
    // Error should appear after async call fails
    const errorElement = await screen.findByRole('alert', {}, { timeout: 3000 });
    expect(errorElement).toBeInTheDocument();
  });
});
