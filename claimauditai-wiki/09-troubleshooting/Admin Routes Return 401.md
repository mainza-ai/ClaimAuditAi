# Admin Routes Return 401

> **Symptom:** Endpoints with `/admin/` in the URL path (e.g., `/api/admin/data/status`, `/api/admin/data/clear`) return HTTP 401 Unauthorized, even though the routes are defined in the Router's URL map and the class compiles successfully. Other routes on the same Router (like `/api/stats`) work fine.

## Root Cause

IRIS CSP (the web application layer) blocks requests to paths containing `/admin/`. This is a security restriction enforced at the CSP web application level — not in the Router class or in the URL map. The CSP dispatcher returns 401 before the request ever reaches `%CSP.REST` dispatch.

The exact mechanism appears to be a system-level path protection in the IRIS web server that prevents unauthenticated access to URL segments matching `admin`.

## Fix

Rename the routes to avoid the `/admin/` path prefix. The functional endpoints now use `/system/`:

| Old Path | New Path | Method |
|----------|----------|--------|
| `/api/admin/data/clear` | `/api/system/clear` | POST |
| `/api/admin/data/status` | `/api/system/status` | GET |
| `/api/admin/data/upload` | `/api/system/upload` | POST |

The Router URL Map was updated:
```xml
<Route Url="/system/clear"  Method="POST" Call="ClearAllData"/>
<Route Url="/system/status" Method="GET"  Call="GetDataStatus"/>
<Route Url="/system/upload" Method="POST" Call="UploadClaimData"/>
```

The frontend API calls were updated in `DataManagement.tsx` to use the new paths.

## Note
This issue is specific to the IRIS private web server. It does not affect the FHIR endpoint at `/fhir/r4` and does not affect any routes without `/admin/` in the path segment.

## Affected Files
- `src/cls/ClaimAudit/REST/Router.cls` — URL Map and method names
- `ui/src/views/DataManagement.tsx` — API path references

## Verification
```bash
# Should return JSON with resource counts (not 401)
curl -s http://localhost:3000/api/system/status

# Should clear all data and return success
curl -s -X POST http://localhost:3000/api/system/clear
```
