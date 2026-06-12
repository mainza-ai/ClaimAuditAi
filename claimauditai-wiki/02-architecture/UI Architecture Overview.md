# UI Architecture Overview

> The ClaimAuditAI frontend is a React single-page application with TypeScript, providing dashboards for claim adjudication, graph visualization, LLM provider configuration, and user management.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | React 19 + TypeScript |
| Build | Vite 6 |
| Routing | React Router 7 |
| State (server) | TanStack React Query 5 |
| State (client) | Zustand 5 |
| HTTP client | Axios |
| Dates | date-fns 4 |
| Graph visualization | Cytoscape.js |
| Styling | Tailwind CSS 4 |
| Proxy | nginx (dev & prod) |

## Page Structure

```
App.tsx
  │
  ├── LoginPage          /login
  ├── App layout (authenticated)
  │   ├── Sidebar
  │   ├── TopBar
  │   │   └── ThemeToggle (light/dark)
  │   └── Main content
  │       ├── Dashboard           /         — Analytics overview
  │       ├── HoldQueue           /claims   — Pended claims table
  │       ├── ClaimDetail         /claims/:id — Single claim detail
  │       ├── GraphView           /graph    — Collusion network visualization
  │       ├── Ledger              /ledger   — Audit override audit trail
  │       ├── DataManagement      /data     — System admin tools
  │       ├── LLMSettings         /settings/llm — LLM provider config
  │       └── UserManagement      /admin/users — User CRUD
```

### Views

| View | Route | Purpose |
|------|-------|---------|
| `Dashboard` | `/` | Summary stats (total held, pending, approved, anomaly trends) |
| `HoldQueue` | `/claims` | Sortable/filterable table of pended claims |
| `ClaimDetail` | `/claims/:id` | Full claim view with adjudication report, decision buttons, chat assistant |
| `GraphView` | `/graph` | Cytoscape.js interactive graph of provider-patient network |
| `Ledger` | `/ledger` | Searchable history of all override decisions |
| `DataManagement` | `/data` | System clear, upload, retrain model |
| `LLMSettings` | `/settings/llm` | Provider selection, API keys, model, rate limit, cache TTL |
| `UserManagement` | `/admin/users` | Create/edit/delete users and assign roles |

### Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `Sidebar` | `layout/` | Navigation with role-based visibility |
| `TopBar` | `layout/` | User info, theme toggle, logout |
| `ThemeToggle` | `layout/` | Light/dark mode switch (persisted to Zustand) |
| `ClaimRow` | `claims/` | Single row in the HoldQueue table |
| `DecisionModal` | `claims/` | Approve/escalate/reject confirmation modal |
| `DispositionReader` | `claims/` | Parses and renders structured tier scores from `parse_disposition()` |
| `RiskBadge` | `claims/` | Color-coded risk score badge |
| `TierPanel` | `claims/` | Expandable panel for each tier's findings |
| `AssistantInput` | `assistant/` | Chat input bar for the audit assistant |
| `AuditAssistant` | `assistant/` | Full chat panel with message history and streaming |
| `MessageBubble` | `assistant/` | Individual chat message display |
| `StatCard` | `stats/` | Single metric card on dashboard |
| `ErrorBoundary` | — | React error boundary with fallback UI |

## Data Flow

```
React Component
    │
    ▼
API Client Layer (api/*.ts)
    │  TanStack Query (useQuery / useMutation)
    ▼
Axios
    │  Base URL: /api (proxied by nginx)
    ▼
IRIS REST API (Router.cls)
    │
    ▼
Response → React Component re-render
```

### API Client Modules

| Module | Base Path | Key Endpoints |
|--------|-----------|---------------|
| `api/auth.ts` | `/auth` | `login`, `introspect` |
| `api/claims.ts` | `/claims` | `held`, `:id`, `approve`, `reject`, `escalate`, `reaudit`, `export` |
| `api/stats.ts` | `/stats` | `trends`, `model-performance` |
| `api/ledger.ts` | `/ledger` | Full ledger query |
| `api/chat.ts` | `/chat` | Send message, stream, get history |

## State Management

### Server State (TanStack Query)

All API data is fetched and cached via TanStack Query hooks. Mutations invalidate relevant query caches to keep the UI in sync.

### Client State (Zustand)

| Store | State | Purpose |
|-------|-------|---------|
| `themeStore` | `theme: "light" | "dark"` | Persisted theme preference |
| `roleStore` | `role`, `username` | Current user's role and identity (set after login) |
| `chatStore` | `messages`, `isStreaming` | Active chat session state |

## Authentication Flow

```
LoginPage
  │ POST /auth/login { username, password }
  ▼
Server returns { token, roles, fullName }
  │
  ▼
Store in memory (roleStore)
  │
  ▼
All subsequent requests include
  Authorization: Bearer <token>
  │
  ▼
/api/auth/introspect validates token
```

## Permissions

The UI enforces role-based access at the component level via `utils/permissions.ts`:

| Permission | Required Role | Applied To |
|------------|---------------|------------|
| `canViewDashboard` | Viewer+ | Dashboard |
| `canViewClaims` | Viewer+ | HoldQueue, ClaimDetail |
| `canDecide` | Specialist+ | DecisionModal (approve/escalate/reject) |
| `canReaudit` | Admin | Reaudit button |
| `canManageUsers` | Admin | UserManagement |
| `canManageSettings` | Admin | LLMSettings |
| `canViewGraph` | Viewer+ | GraphView |

## Development

```bash
cd ui/
npm install
npm run dev        # Vite dev server on :5173
npm run build      # Production build to dist/
npm run test       # Vitest
npm run lint       # ESLint
```

The production build is served by nginx (`ui/nginx.conf`) which proxies `/api/*` requests to the IRIS REST server and serves static assets from the `dist/` directory.

## See Also

[[System Architecture Overview]] · [[API Endpoints]] · [[SMART on FHIR with Keycloak OAuth2]]
