# Dashboard Metrics Stale After Actions

> **Symptom:** After approving, rejecting, or escalating a claim, the Dashboard continues to show stale metrics (held count doesn't change, approved today stays at 0). The HoldQueue still displays claims that were just acted upon.

## Root Causes

### 1. No Auto-Refresh on Dashboard Queries
The Dashboard `useQuery` calls had no `refetchInterval` configured, despite the UI showing "Refreshes every 15s". Queries ran once on mount and never updated.

### 2. Stale HoldQueue Cache After Navigation
`ClaimDetail.handleSuccess` called:
```typescript
queryClient.invalidateQueries({ queryKey: ['claims', 'held'], refetchType: 'active' });
```
Since the HoldQueue component is unmounted while the user is on ClaimDetail, there are **no active observers** for the `['claims', 'held']` query. With `refetchType: 'active'`, React Query marks the cache as stale but does NOT trigger a refetch. When the user navigates back to `/queue`, the component mounts and renders the stale cached data first, then re-fetches — causing a visible flash of stale data.

## Fix

### Add `refetchInterval` to all Dashboard queries:
```typescript
const { data: stats } = useQuery({
  queryKey: ['stats'],
  queryFn: getStats,
  refetchInterval: 15000,  // Added
});
```

### Remove stale HoldQueue cache before navigation:
```typescript
const handleSuccess = () => {
  queryClient.removeQueries({ queryKey: ['claims', 'held'] });  // Clear stale cache
  queryClient.invalidateQueries({ queryKey: ['stats'] });
  queryClient.invalidateQueries({ queryKey: ['ledger'] });
  setModal(null);
  navigate('/queue');
};
```

### Global QueryClient configuration:
```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchInterval: 15000,
      staleTime: 10000,
    },
  },
});
```

## Affected Files
- `ui/src/views/Dashboard.tsx` — Added `refetchInterval` to all useQuery calls
- `ui/src/views/ClaimDetail.tsx` — Changed to `removeQueries` + `invalidateQueries`
- `ui/src/App.tsx` — Added global `refetchInterval` default

## Verification
After making changes, approve a claim and immediately check the Dashboard — held count should decrease within 15 seconds. Navigate from ClaimDetail to HoldQueue — the approved claim should not flash in the list.
