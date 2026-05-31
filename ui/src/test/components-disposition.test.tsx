import React from 'react';
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DispositionReader } from '../components/claims/DispositionReader';

function renderWithProviders(ui: React.ReactElement) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <MemoryRouter>{ui}</MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('DispositionReader', () => {
  it('renders empty state when no markdown', () => {
    renderWithProviders(<DispositionReader markdown="" />);
    expect(screen.getByText(/no adjudication report/i)).toBeInTheDocument();
  });

  it('renders markdown content', () => {
    renderWithProviders(<DispositionReader markdown="## Audit Summary\nThis claim has been reviewed." />);
    expect(screen.getByText(/audit summary/i)).toBeInTheDocument();
  });
});
