# LLM API Key Lost on Settings Save

> **Symptom:** After saving LLM settings via the UI, the configured LLM stops working. The API key is apparently lost.

## Root Cause

The backend had a key name mismatch between what `GetLLMSettings` returned and what `llm_router.py` expected:

- **GetLLMSettings** returned: `nvidiaKeySet` / `openaiKeySet` (booleans indicating key presence)
- **llm_router.py** expected: `nvidiaApiKey` / `openaiApiKey` (actual key values)
- **UpdateLLMSettings** saved the POST body directly, overwriting the existing `.llm_settings.json` file

When the user saved settings via the UI, the POST body contained the current provider config but **not** the API key (which is masked). The save operation completely overwrote the file, deleting the previously configured API key.

## Fix

### 1. Merge settings on save
`UpdateLLMSettings` now reads the existing `.llm_settings.json`, merges the incoming changes on top of it, and writes the merged result. The API key from a previous save survives any subsequent update.

```objectscript
Set tExisting = {}
Try {
    Do tFileEx.LinkToFile(tSettingsPath)
    Set tExisting = ##class(%DynamicObject).%FromJSON(...)
} Catch {}
Set tMerged = tExisting
Set tIter = tBody.%GetIterator()
While tIter.%GetNext(.tKey, .tVal) {
    Do tMerged.%Set(tKey, tVal)
}
```

### 2. Simplify GetLLMSettings
Removed `nvidiaKeySet` / `openaiKeySet` booleans from the response. The settings endpoint no longer exposes key state — the user always sees "Leave blank to keep existing key" as the placeholder.

### 3. Frontend cleanup
Removed `nvidiaKeySet` / `openaiKeySet` from the `LLMSettingsData` type. The UI no longer shows a checkmark when a key is configured in `.env`.

## Affected Files
- `src/cls/ClaimAudit/REST/Router.cls` — `GetLLMSettings()`, `UpdateLLMSettings()`
- `ui/src/views/LLMSettings.tsx` — interface and JSX

## Verification
1. Set an API key via the UI and save
2. Change the model name (leave key blank) and save again
3. The LLM should still work — the key was preserved in the merge
