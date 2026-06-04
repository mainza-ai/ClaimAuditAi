# Seed Data Disposition Validation

> The "Seed Sample Data" button returns HTTP 200 with "success" but no ClaimResponses are created, and the dashboard remains empty.

### Symptom
- Clicking **Seed Sample Data** briefly shows "Seeding..." then returns to normal
- Dashboard still shows `0` claims on hold
- API returns `{"status":"success","message":"Successfully ingested 8 FHIR Claims..."}`
- Checking `^ClaimAuditStatusLog` reveals `status=400` errors for ClaimResponse, Task, and CommunicationRequest creation
- Error text: `MalformedValue` or `MalformedRelativeReference`

### Root Causes

#### 1. Emoji and CRLF Characters in Disposition Text
The `ClaimAudit.AI.Agent` class generates a fallback disposition summary when the LLM agent fails (e.g., missing API key). The original fallback contained emoji characters and `$Char(13,10)` (CRLF):

```objectscript
Set summary = "# ⚠️ Payment Integrity ..." _ $Char(13, 10) _
              "### 🔍 Flagged Discrepancy Summaries:" ...
```

The FHIR string validation regex `[\\r\\n\\t\\u0020-\\uFFFF]*` rejects:
- Characters above U+FFFF (Supplementary Multilingual Plane), such as 🔍 (U+1F50D)
- Some control characters if not properly allowed
- The `###` markdown headers are fine, but the emoji rendering as `?` in IRIS output caused the string to contain unexpected bytes

**Fix:** Remove all emoji characters and `$Char(13,10)` from the fallback. Use plain text only:

```objectscript
Set summary = "Payment Integrity Adjudication HOLD Notification. " _
              "Flagged Discrepancy Summaries: " _
              "Adjudication engine encountered an internal exception: " _ ex.DisplayString()
```

#### 2. Empty Claim Reference (`request: "Claim/"`)
The `Interactions.cls::OnAfterRequest` creates a ClaimResponse with `request: { reference: "Claim/" _ claimId }`. The `claimId` was obtained from `pFHIRResponse.Id`, which was always empty during POST creation because the FHIR framework hadn't set the response ID before the interceptor ran.

**Fix:** Add `pFHIRRequest.Json.id` as a fallback when `pFHIRResponse.Id` is empty:

```objectscript
Set claimId = pFHIRResponse.Id
If claimId = "" Set claimId = $Piece(pFHIRResponse.ETag, "/", 1)
If claimId = "" Set claimId = pFHIRRequest.Json.id   // fallback to request payload ID
```

#### 3. Missing LLM Credentials
The `agent_orchestrator.py` Python module raises `ValueError: NVIDIA_API_KEY environment variable not set` when the API key is not accessible from Embedded Python. This causes `GenerateHoldSummary` to return the fallback text instead of a proper LLM-generated audit report. The fix for the disposition validation (above) at least allows the ClaimResponse to be created with a meaningful error message.

### Resolution

1. **Update `Agent.cls`** to generate clean plain-text fallback without emojis or CRLF
2. **Update `Interactions.cls`** to fall back to `pFHIRRequest.Json.id` for the claim reference
3. **Verify** by calling the seed endpoint and checking `^ClaimAuditStatusLog` for `status=2xx`

### Autoencoder Training Order

`LoadSampleData` now clears the `ClaimProjections` table **before** the NLP model warm-up (previously the warm-up ran before the table clear). This prevents the autoencoder from training on stale data from a previous seed, which caused evaluation features to mismatch the training distribution.

### Sample Data Distribution

The 8 sample claims have diversified features for testing all risk levels:
- Ages: 23-78, Item counts: 1-4, Duration: 1-7 days
- Providers 1 and 2 share the same address ("100 Main St Suite A, Boston MA") — triggers graph address collision
- Claim 8 uses provider 1 (same address as provider 2) with extreme outlier features (age=29, items=4, days=7) — produces the critical (1.00) test case
- Expected risk distribution: 1 critical, 3 high, 4 medium

### Verification
```bash
# Check how many ClaimResponses were created
echo 'set rs = ##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse") do rs.%Next() w rs.%Get("cnt")' | docker exec -i claimaudit-iris iris session IRIS -U INTEROP

# Check error logs
echo 'zw ^ClaimAuditStatusLog' | docker exec -i claimaudit-iris iris session IRIS -U INTEROP
```

## See Also
[[ObjectScript SQL Single-Quote Consumption]] · [[iris.script Indentation Pitfalls]] · [[AI Hub Tool Invocation Failures]]
