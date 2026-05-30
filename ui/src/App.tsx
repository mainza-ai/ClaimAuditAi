import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Sidebar } from './components/layout/Sidebar';
import { TopBar } from './components/layout/TopBar';
import { AuditAssistant } from './components/assistant/AuditAssistant';
import { Dashboard } from './views/Dashboard';
import { HoldQueue } from './views/HoldQueue';
import { ClaimDetail } from './views/ClaimDetail';
import { GraphView } from './views/GraphView';
import { Ledger } from './views/Ledger';
import { useChatStore } from './store/chatStore';
import { ErrorBoundary } from './components/ErrorBoundary';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchInterval: 15000,
      staleTime: 10000,
    },
  },
});

export default function App() {
  const isOpen = useChatStore((s) => s.isOpen);

  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <div
          style={{
            display: 'flex',
            height: '100vh',
            backgroundColor: 'var(--bg-page)',
            color: 'var(--text-primary)',
            overflow: 'hidden',
          }}
        >
          <Sidebar />
          <div className={`flex flex-col flex-1 min-w-0 transition-all duration-300 ${isOpen ? 'mr-96' : ''}`}
            style={{ backgroundColor: 'var(--bg-page)' }}
          >
            <TopBar />
            <main
              style={{
                flex: 1,
                overflowY: 'auto',
                padding: 24,
                backgroundColor: 'var(--bg-page)',
              }}
            >
              <ErrorBoundary>
              <Routes>
                <Route path="/" element={<Navigate to="/dashboard" replace />} />
                <Route path="/dashboard" element={<Dashboard />} />
                <Route path="/queue" element={<HoldQueue />} />
                <Route path="/claims/:id" element={<ClaimDetail />} />
                <Route path="/graph" element={<GraphView />} />
                <Route path="/ledger" element={<Ledger />} />
              </Routes>
              </ErrorBoundary>
            </main>
          </div>
          <AuditAssistant />
        </div>
      </BrowserRouter>
    </QueryClientProvider>
  );
}