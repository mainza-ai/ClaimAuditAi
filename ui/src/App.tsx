import { Suspense, lazy } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Sidebar } from './components/layout/Sidebar';
import { TopBar } from './components/layout/TopBar';
import { useChatStore } from './store/chatStore';
import { getCurrentClaims } from './api/auth';
import { ErrorBoundary } from './components/ErrorBoundary';

const Dashboard = lazy(() => import('./views/Dashboard').then(m => ({ default: m.Dashboard })));
const HoldQueue = lazy(() => import('./views/HoldQueue').then(m => ({ default: m.HoldQueue })));
const ClaimDetail = lazy(() => import('./views/ClaimDetail').then(m => ({ default: m.ClaimDetail })));
const GraphView = lazy(() => import('./views/GraphView').then(m => ({ default: m.GraphView })));
const Ledger = lazy(() => import('./views/Ledger').then(m => ({ default: m.Ledger })));
const LLMSettings = lazy(() => import('./views/LLMSettings').then(m => ({ default: m.LLMSettings })));
const DataManagement = lazy(() => import('./views/DataManagement').then(m => ({ default: m.DataManagement })));
const LoginPage = lazy(() => import('./views/LoginPage').then(m => ({ default: m.LoginPage })));
const AuditAssistant = lazy(() => import('./components/assistant/AuditAssistant').then(m => ({ default: m.AuditAssistant })));

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchInterval: 15000,
      staleTime: 10000,
    },
  },
});

function PageSkeleton() {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '64px 0',
        color: 'var(--text-secondary)',
        fontSize: 14,
        gap: 10,
      }}
    >
      <div
        style={{
          width: 16,
          height: 16,
          border: '2px solid var(--border-default)',
          borderTopColor: 'var(--accent-primary)',
          borderRadius: '50%',
          animation: 'spin 0.6s linear infinite',
        }}
      />
      Loading...
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

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
            <Suspense fallback={<PageSkeleton />}>
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
            </Suspense>
          </ErrorBoundary>
        </main>
      </div>
      <Suspense fallback={null}>
        <AuditAssistant />
      </Suspense>
    </div>
  );
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Suspense fallback={<PageSkeleton />}><LoginPage /></Suspense>} />
          <Route path="/*" element={<ProtectedLayout />} />
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
