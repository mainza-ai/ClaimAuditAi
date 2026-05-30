# ObjectScript SQL Single-Quote Consumption

> ObjectScript treats single quotes (`'...'`) as string delimiters, stripping them from inside double-quoted strings. This causes SQL string literals to lose their quotes, producing invalid SQL.

### Symptom
- API returns `{"error":"<METHOD DOES NOT EXIST> *%Get,%SQL.StatementResult"}`
- The error offset points to `%Get("cnt")` or `%Get("columnName")` calls in REST Router methods
- Example: `GetStats+7^ClaimAudit.REST.Router.1 *%Get,%SQL.StatementResult`

### Root Cause
ObjectScript accepts both double quotes (`"..."`) and single quotes (`'...'`) as string delimiters. When a double-quoted string contains single quotes, ObjectScript interprets the single-quoted portions as separate strings and auto-concatenates them — removing the single quotes from the result.

For example, this ObjectScript code:

```objectscript
Set sql = "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome='queued'"
```

Is parsed by ObjectScript as:

```objectscript
"SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome=" + 'queued' + ""
```

The single quotes around `queued` are **consumed**, producing:

```sql
SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome=queued
```

This is **invalid SQL** — string values must be quoted. The SQL query fails with `SQLCODE=-29` or similar, and the `%Get("cnt")` call on the failed result set throws `<METHOD DOES NOT EXIST>`.

### Resolution

#### Replace Single Quotes with Bind Parameters
**Never use single quotes inside ObjectScript `"..."` strings passed to `%ExecDirect`.** Instead, use `?` placeholders and pass values as bind parameters:

```objectscript
// ❌ BAD — single quotes are consumed
Set tRS = ##class(%SQL.Statement).%ExecDirect(,
  "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome='queued'")

// ✅ GOOD — bind parameters preserve the string
Set tRS = ##class(%SQL.Statement).%ExecDirect(,
  "SELECT COUNT(*) AS cnt FROM HSFHIR_X0001_S.ClaimResponse WHERE outcome=?", "queued")
```

#### Fixing `$PIECE` with Single-Quote Delimiters
`$PIECE` calls inside SQL strings are also affected:

```objectscript
// ❌ BAD — '/' loses its quotes
"JOIN Claim ON Claim.Key = $PIECE(CR.request.reference, '/' ,2)"

// ✅ GOOD — use $CHAR(47) for the forward slash
"JOIN Claim ON Claim.Key = $PIECE(CR.request.reference, $CHAR(47), 2)"
```

#### Fixing `LIKE` Patterns
Patterns with `%` and single quotes also break:

```objectscript
// ❌ BAD — '%Claim/' loses quotes
"WHERE about LIKE '%Claim/" _ tClaimId _ "%'"

// ✅ GOOD — use bind parameter for the entire pattern
"WHERE about LIKE ?", "%Claim/" _ tClaimId _ "%"
```

#### Fixing `IN` Lists
```objectscript
// ❌ BAD — 'completed','ready' lose quotes
"WHERE status IN ('completed','ready')"

// ✅ GOOD — use multiple bind parameters
"WHERE status IN (?,?)", "completed", "ready"
```

### Affected Queries
The following SQL patterns in `src/cls/ClaimAudit/REST/Router.cls` were all fixed by converting to bind parameters:

| Method | Original Pattern | Fix |
|--------|-----------------|-----|
| `GetHeldClaims` | `outcome = 'queued'` | `outcome = ?`, `"queued"` |
| `GetClaimDetail` | `focus = 'Claim/...'` | `focus = ?`, `"Claim/" _ id` |
| `GetStats` | `outcome='queued'` | `outcome=?`, `"queued"` |
| `GetStats` | `outcome='complete'` | `outcome=?`, `"complete"` |
| `GetTrends` | `outcome='queued'` | `outcome=?`, `"queued"` |
| `GetTrends` | `outcome='complete'` | `outcome=?`, `"complete"` |
| `GetTrends` | `$PIECE(..., '/' ,2)` | `$CHAR(47)` |
| `GetLedger` | `status IN ('completed','ready')` | `IN (?,?)` |

## See Also
[[Blank UI Due to API Error Responses]] · [[FHIR Server 404]]
