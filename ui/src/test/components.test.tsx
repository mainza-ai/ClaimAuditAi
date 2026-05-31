import React from 'react';
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { RiskBadge } from '../components/claims/RiskBadge';

describe('RiskBadge', () => {
  it('renders critical level with score', () => {
    render(<RiskBadge level="critical" score={0.92} />);
    expect(screen.getByText(/critical.*0\.92/)).toBeInTheDocument();
  });

  it('renders high level', () => {
    render(<RiskBadge level="high" score={0.70} />);
    expect(screen.getByText(/high/)).toBeInTheDocument();
  });

  it('renders medium level', () => {
    render(<RiskBadge level="medium" score={0.45} />);
    expect(screen.getByText(/medium/)).toBeInTheDocument();
  });

  it('renders low level with fallback styles', () => {
    render(<RiskBadge level="low" score={0.10} />);
    expect(screen.getByText(/low/)).toBeInTheDocument();
  });
});
