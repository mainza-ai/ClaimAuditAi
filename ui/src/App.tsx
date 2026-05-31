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
import { LLMSettings } from './views/LLMSettings';
import { DataManagement } from './views/DataManagement';
import { LoginPage } from './views/LoginPage';
import { useChatStore } from './store/chatStore';
import { getCurrentClaims } from './api/auth';
import { ErrorBoundary } from './components/ErrorBoundary';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchInterval: 15000,
      staleTime: 10000,
    },
  },
});

function ProtectedLayout() {
  const isOpen = useChatStore((s) => s.isOpen);
  const claims = getCurrentClaims();

  if (!claims) {
    return <Navigate to="/login" replace />;
  }

  return (
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
      <div
        className={`flex flex-col flex-1 min-w-0 transition-all duration-300 ${isOpen ? 'mr-96' : ''}`}
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
              <Route path="/settings/llm" element={<LLMSettings />} />
              <Route path="/admin/data" element={<DataManagement />} />
              <Route
                path="*"
                element={
                  <div style={{ textAlign: 'center', padding: '64px 0', color: 'var(--text-secondary)' }}>
                    <h2 style={{ fontSize: 24, fontWeight: 600, margin: 0 }}>404</h2>
                    <p style={{ margin: '8px 0 0', fontSize: 14 }}>This page does not exist.</p>
                  </div>
                }
              />
            </Routes>
          </ErrorBoundary>
        </main>
      </div>
      <AuditAssistant />
    </div>
  );
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/*" element={<ProtectedLayout />} />
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
