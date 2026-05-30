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
    console.error('ErrorBoundary caught:', error, info.componentStack);
  }

  render() {
    if (!this.state.hasError) return this.props.children;

    return (
      <div className="flex flex-col items-center justify-center h-full text-gray-400 font-mono p-8 text-center">
        <span className="text-red-400 text-3xl mb-4">!</span>
        <p className="text-sm mb-2">Something went wrong</p>
        <p className="text-xs text-gray-600 max-w-md mb-4">
          {this.state.error?.message}
        </p>
        <button
          onClick={() => this.setState({ hasError: false, error: null })}
          className="text-xs px-3 py-1.5 bg-gray-800 border border-gray-700 rounded hover:border-gray-600 transition-colors"
        >
          Try again
        </button>
      </div>
    );
  }
}
