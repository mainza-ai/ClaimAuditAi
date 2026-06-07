# Blank UI Due to API Error Responses

> The React UI renders a blank page when API endpoints return HTML or JSON error objects instead of the expected JSON arrays.

### Symptom
- Browser shows white/blank page with no content
- Console error: `TypeError: o.filter is not a function`
- Stack trace points to minified React/React Query code attempting `.filter()` on API response data

### Root Cause
The frontend uses `@tanstack/react-query` to fetch data from the `/api/*` endpoints. When the API returns an error (e.g., HTTP 404 with HTML body, or HTTP 200 with `{"error":"..."}` JSON), the raw response data is passed to React Query as the `data` value. If a component then calls `.filter()` on it (expecting an array), it crashes with `TypeError: o.filter is not a function` because it received a string or object instead of an array.

This typically happens when:
1. The `/api` web application is not registered in IRIS (returns HTML 404)
2. The FHIR server or its SQL tables are not set up (SQL queries fail, errors returned as JSON)
3. The IRIS CSP gateway returns an HTML error page

### Resolution

#### 1. Add an Axios Response Interceptor
In `ui/src/api/client.ts`, add a response interceptor that rejects responses containing error fields:

```typescript
apiClient.interceptors.response.use(
  (response) => {
    const d = response.data;
    if (d && typeof d === 'object' && !Array.isArray(d) && (d.error || d.errors)) {
      const msg = d.error || (d.errors && d.errors[0]?.error) || 'Unknown server error';
      return Promise.reject(new Error(msg));
    }
    return response;
  },
  (error) => {
    const d = error.response?.data;
    const msg = d?.error || (d?.errors && d?.errors[0]?.error) || error.message || 'Network error';
    return Promise.reject(new Error(msg));
  },
);
```

#### 2. Guard Array-Returning API Functions
Wrap every API function that should return an array with `Array.isArray` fallback:

```typescript
export const getHeldClaims = () =>
  apiClient.get<HeldClaim[]>('/claims/held').then((r) => Array.isArray(r.data) ? r.data : []);

export const getTrends = () =>
  apiClient.get<TrendDay[]>('/stats/trends').then((r) => Array.isArray(r.data) ? r.data : []);
```

This ensures components always receive an array even when the API fails, preventing `.filter()` crashes.

#### 3. Verify Backend Endpoints
Ensure all backend prerequisites are met before testing the UI:
- `/api` web app is registered in `%SYS` (`Security.Applications.Exists("/api") = 1`)
- FHIR server is provisioned at `/fhir/r4`
- FHIR schema tables exist (`HSFHIR_X0001_S.ClaimResponse`)
- REST Router class is compiled (`ClaimAudit.REST.Router`)

## See Also
[[ObjectScript SQL Single-Quote Consumption]] · [[FHIR Server 404]] · [[iris.script Indentation Pitfalls]]
