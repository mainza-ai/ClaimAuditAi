# Dashboard Daily Counts Always Zero

> **Symptom:** The "Claims Intercepted (Daily)" chart on the Dashboard shows 0 for every day, including today, even though claims have been seeded/submitted.

## Root Cause

The SQL query used `CAST(_lastUpdated AS DATE) = '2026-05-31'` for date comparison. In IRIS FHIR SQL projections, `_lastUpdated` is stored as a string in ISO 8601 format (e.g., `"2026-05-31T02:19:28Z"`). When cast to `DATE`, IRIS returns the horolog integer (e.g., `67721`), NOT a formatted date string.

The comparison `67721 = '2026-05-31'` (integer vs string) always returns false, producing zero counts.

## Fix

Replace `CAST(_lastUpdated AS DATE) = ?` with `SUBSTRING(_lastUpdated, 1, 10) = ?`:

```sql
-- Before (always returns 0)
SELECT COUNT(*) FROM HSFHIR_X0001_S.ClaimResponse
WHERE CAST(_lastUpdated AS DATE) = ?

-- After (correctly matches date prefix)
SELECT COUNT(*) FROM HSFHIR_X0001_S.ClaimResponse
WHERE SUBSTRING(_lastUpdated, 1, 10) = ?
```

The `_lastUpdated` value is stored as `"2026-05-31T02:19:28Z"`, so `SUBSTRING(..., 1, 10)` extracts `"2026-05-31"` for correct date matching.

## Additional Related Issue: Trend Day Names

The `GetTrends` method used `$ZDATE(tDate, 11)` to get the day-of-week abbreviation. However, `$ZDATE(date, 11)` returns the abbreviation as a **string** (e.g., `"Mon"`), not a number. When added with `+ 1`, the string `"Mon"` coerces to `0`, making every day show as `"Sun"` from `$LISTGET(tDays, 1)`.

**Fix:** Use `$ZDATE(tDate, 11)` directly — it already returns the correct abbreviation.

```objectscript
// Before: always returns "Sun"
Set tDow = $LISTGET(tDays, $ZDATE(tDate, 11) + 1)

// After: returns correct day abbreviation
Set tDow = $ZDATE(tDate, 11)
```

## Affected Files
- `src/cls/ClaimAudit/REST/Router.cls` — `GetStats()` and `GetTrends()` methods (5 occurrences)

## Verification
After seeding data, the daily intercepted chart should show `count=8` for the current date (today) when 8 claims are in the repository.
