import { Component, type ReactNode, type ErrorInfo } from 'react';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    // eslint-disable-next-line no-console
    console.error('ErrorBoundary caught:', error, info.componentStack);
  }

  render() {
    if (!this.state.hasError) return this.props.children;

    return (
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          height: '100%',
          color: 'var(--text-secondary)',
          fontFamily: 'var(--font-mono)',
          padding: 32,
          textAlign: 'center',
        }}
      >
        <span style={{ color: 'var(--color-danger)', fontSize: 32, marginBottom: 16 }}>!</span>
        <p style={{ fontSize: 14, marginBottom: 8 }}>Something went wrong</p>
        <p style={{ fontSize: 12, color: 'var(--text-tertiary)', maxWidth: 448, marginBottom: 16 }}>
          {this.state.error?.message}
        </p>
        <button
          onClick={() => this.setState({ hasError: false, error: null })}
          style={{
            fontSize: 12,
            padding: '6px 12px',
            cursor: 'pointer',
            backgroundColor: 'var(--bg-card)',
            border: '1px solid var(--border-default)',
            borderRadius: 6,
            color: 'var(--text-secondary)',
          }}
        >
          Try again
        </button>
      </div>
    );
  }
}
