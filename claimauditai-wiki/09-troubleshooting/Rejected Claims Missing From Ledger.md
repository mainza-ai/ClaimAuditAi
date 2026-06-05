# Override Audit Ledger & Action History Synchronization

> **Symptoms:** 
> 1. After approving or rejecting a claim, it leaves the hold queue but does not appear in the audit ledger, or approved claims incorrectly display the orange `ESCALATED` badge instead of the green `APPROVED` badge.
> 2. The ledger's "Rationale / Override Note" column displays the automated system adjudication report rather than the custom human explanation entered during approval/rejection.
> 3. The claim details page's "Override Decision Resolved" status card displays the first action's details (escalation details) instead of the latest action (final director approval/rejection details).

---

## 1. Approved Claims Mislabeled as Escalated

### Root Cause
The `GetLedger()` API endpoint (in [Router.cls](file:///Users/mck/Desktop/claimauditai/src/cls/ClaimAudit/REST/Router.cls)) retrieves auditing tasks and classifies their actions. The original logic checked if the task priority was `"stat"` (indicating an escalation) before evaluating its execution status:

```objectscript
// Before: Priority check preempted status check
If tPriority = "stat" {
    Set tAction = "escalated"
} ElseIf tStatus = "completed" {
    Set tAction = "approved"
} ElseIf tStatus = "cancelled" {
    Set tAction = "rejected"
}
```

Since escalated claims retain their `"stat"` priority after they are approved or rejected, they were incorrectly classified as `"escalated"` in the ledger.

### Fix
Refactored the classification logic to check the final completion status first, falling back to priority classification only if the task is not resolved:

```objectscript
// After: Status check evaluated first
Set tAction = "escalated"
If tStatus = "completed" {
    Set tAction = "approved"
} ElseIf tStatus = "cancelled" {
    Set tAction = "rejected"
}
```

---

## 2. Missing Manual Override Rationale in Ledger

### Root Cause
During override actions (escalate/approve/reject), human rationales are written to the `ClaimResponse` resource inside a custom FHIR extension (`https://claimauditai.com/fhir/extension/rationale`). The original `GetLedger()` endpoint did not check for this extension, defaulting to the automated `disposition` adjudication text.

### Fix
Updated the `GetLedger()` endpoint to parse the `ClaimResponse` resource extensions and extract the human rationale:

```objectscript
// Parse extensions for authorized-by and rationale
Set tExtJson = tCRJson.extension
If $IsObject(tExtJson) {
    Set tExtIter = tExtJson.%GetIterator()
    While tExtIter.%GetNext(.tK, .tExt) {
        If tExt.url = "https://claimauditai.com/fhir/extension/authorized-by" {
            Set tAuthorizedBy = tExt.valueString
        } ElseIf tExt.url = "https://claimauditai.com/fhir/extension/rationale" {
            Set tRationale = tExt.valueString
        }
    }
}
```

If the human rationale exists, it is displayed directly in the Override Note column. If not, the system falls back to the automated report disposition snippet.

---

## 3. Stale Action History in Detail Page Status Card

### Root Cause
The decision banner card on the details page (in [ClaimDetail.tsx](file:///Users/mck/Desktop/claimauditai/ui/src/views/ClaimDetail.tsx)) displays the authorizer, decision timestamp, and rationale. It retrieved these by searching `claim.actionHistory`:

```typescript
// Before: find() returned the FIRST history event (the escalation)
const authorizer = claim.actionHistory.find((h) => h.type === 'authorized-by')?.value;
const decidedAt = claim.actionHistory.find((h) => h.type === 'decision-timestamp')?.value;
const rationale = claim.actionHistory.find((h) => h.type === 'rationale')?.value;
```

Since the history array is compiled chronologically, the first entry matching these keys is the escalation event, causing the card to show stale data.

### Fix
Refactored the frontend to reverse the history log array before searching, returning the most recent (latest) action:

```typescript
// After: Reversing a copy of the history array before finding
const authorizer = [...claim.actionHistory].reverse().find((h) => h.type === 'authorized-by')?.value;
const decidedAt = [...claim.actionHistory].reverse().find((h) => h.type === 'decision-timestamp')?.value;
const rationale = [...claim.actionHistory].reverse().find((h) => h.type === 'rationale')?.value;
```

---

## Affected Files
* **Backend API Routing**: [Router.cls](file:///Users/mck/Desktop/claimauditai/src/cls/ClaimAudit/REST/Router.cls)
* **Frontend Claim Detail Page**: [ClaimDetail.tsx](file:///Users/mck/Desktop/claimauditai/ui/src/views/ClaimDetail.tsx)

---

## Verification & Manual Testing

1. **Verify Ledger Endpoint Output**:
   Submit a GET request to `/api/ledger` and verify the action and rationales:
   ```bash
   curl -s http://localhost:52773/api/ledger -H "Authorization: Bearer <TOKEN>"
   ```
   Assert that:
   * Approved claims return `"action": "approved"`.
   * The `"reason"` field matches the human rationale entered during the approval step.

2. **Verify Claim Detail Page**:
   Open a resolved claim in the UI and verify that the "Override Decision Resolved" card displays the latest decision authorizer (e.g. `ClaimAuditAI Director`) and the custom approval rationale rather than the auditor's escalation note.

---

## See Also
[[Claim Actions Silently Fail]] · [[Dashboard Metrics Stale After Actions]] · [[Troubleshooting Overview]]
