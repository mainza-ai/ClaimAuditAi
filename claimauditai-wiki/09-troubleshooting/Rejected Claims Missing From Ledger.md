# Rejected Claims Missing From Ledger

> **Symptom:** After rejecting a claim via `POST /api/claims/:id/reject`, the claim leaves the hold queue but does not appear in the audit ledger. The ledger shows zero "rejected" entries. OR: after escalating a claim, no ledger entry appears and the escalation badge does not show.

## Root Cause

The `GetLedger` SQL query filters by Task status and priority. Two independent bugs caused entries to be invisible:

1. **Rejected claims (cancelled status):** The original query only matched `status IN ('completed','ready')` — it never included `status='cancelled'`. When `RejectClaim` sets Task `status = "cancelled"`, rejected claims were invisible.

2. **Escalated claims (stat priority):** The query required `(status = 'ready' AND priority = 'stat')` — but `EscalateClaim` always moved the Task status from `'ready'` to `'requested'` on escalation. This condition was impossible to reach. The `EscalateClaim` method also only set `priority="stat"` on the *second* escalation, leaving the first escalation invisible to the GetHeldClaims badge check.

When `RejectClaim` executes, it sets:
- ClaimResponse `outcome = "error"`
- Task `status = "cancelled"`

## Fix

Include cancelled tasks and match escalated tasks by priority alone (regardless of status):

```objectscript
// Before (only completed + ready; escalated check unreachable):
Set tRS = ##class(%SQL.Statement).%ExecDirect(,
"SELECT ... FROM HSFHIR_X0001_S.Task "_
"WHERE status IN (?,?) OR (status = ? AND priority = ?) ORDER BY ...",
"completed", "cancelled", "ready", "stat")

// After (completed + cancelled + any task with priority=stat):
Set tRS = ##class(%SQL.Statement).%ExecDirect(,
"SELECT ... FROM HSFHIR_X0001_S.Task "_
"WHERE status IN (?,?) OR priority = ? ORDER BY ...",
"completed", "cancelled", "stat")

// Action classification
If tStatus = "cancelled" {
    Set tAction = "rejected"
} ElseIf tPriority = "stat" {
    Set tAction = "escalated"
}
```

EscalateClaim also fixed to set `priority="stat"` on **every** escalation (not just second), and all escalations now transition `ready → requested` with `priority="stat"` immediately.

## Affected Files
- `src/cls/ClaimAudit/REST/Router.cls` — `GetLedger()`, `EscalateClaim()`

## Verification
```bash
# Reject a claim
curl -s -X POST http://localhost:52773/api/claims/21/reject \
  -H 'Content-Type: application/json' \
  -d '{"authorizedBy":"Director Jane","rationaleSummary":"Upcoding detected."}'

# Escalate a claim
curl -s -X POST http://localhost:52773/api/claims/22/escalate \
  -H 'Content-Type: application/json' \
  -d '{"authorizedBy":"Auditor","rationaleSummary":"Needs director review."}'

# Check ledger — should show both a "rejected" and "escalated" entry
curl -s http://localhost:52773/api/ledger | python3 -c "
import json,sys
entries = json.load(sys.stdin)['data']
rejected = [e for e in entries if e['action'] == 'rejected']
escalated = [e for e in entries if e['action'] == 'escalated']
print(f'{len(rejected)} rejected, {len(escalated)} escalated entries found')
"
```

## See Also
[[Claim Actions Silently Fail]] · [[Dashboard Metrics Stale After Actions]]
