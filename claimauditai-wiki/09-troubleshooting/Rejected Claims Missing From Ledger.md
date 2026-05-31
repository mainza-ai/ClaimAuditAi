# Rejected Claims Missing From Ledger

> **Symptom:** After rejecting a claim via `POST /api/claims/:id/reject`, the claim leaves the hold queue but does not appear in the audit ledger. The ledger shows zero "rejected" entries.

## Root Cause

The `GetLedger` SQL query filtered Tasks by `status IN ('completed','ready')` — it never included `status='cancelled'`.

When `RejectClaim` executes, it sets:
- ClaimResponse `outcome = "error"`
- Task `status = "cancelled"`

Since cancelled tasks were excluded from the query, rejected claims were completely invisible in the ledger.

## Fix

Add `"cancelled"` to the ledger query and classify cancelled tasks as `action = "rejected"`:

```objectscript
// Before (only completed + ready)
Set tRS = ##class(%SQL.Statement).%ExecDirect(,
"SELECT ... FROM HSFHIR_X0001_S.Task "_
"WHERE status IN (?,?) ORDER BY ...", "completed", "ready")

// After (completed + cancelled + escalated)
Set tRS = ##class(%SQL.Statement).%ExecDirect(,
"SELECT ... FROM HSFHIR_X0001_S.Task "_
"WHERE status IN (?,?) OR (status = ? AND priority = ?) ORDER BY ...",
"completed", "cancelled", "ready", "stat")

// Classification
If tStatus = "cancelled" {
    Set tAction = "rejected"
} ElseIf (tStatus = "ready") && (tPriority = "stat") {
    Set tAction = "escalated"
}
```

## Affected Files
- `src/cls/ClaimAudit/REST/Router.cls` — `GetLedger()`

## Verification
```bash
# Reject a claim
curl -s -X POST http://localhost:3000/api/claims/21/reject \
  -H 'Content-Type: application/json' \
  -d '{"authorizedBy":"Director Jane","rationaleSummary":"Upcoding detected."}'

# Check ledger — should show a "rejected" entry
curl -s http://localhost:3000/api/ledger | python3 -c "
import json,sys
entries = json.load(sys.stdin)
rejected = [e for e in entries if e['action'] == 'rejected']
print(f'{len(rejected)} rejected entries found')
"
```

## See Also
[[Claim Actions Silently Fail]] · [[Dashboard Metrics Stale After Actions]]
