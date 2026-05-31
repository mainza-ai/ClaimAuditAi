# Theme Not Applied on Page Load

> **Symptom:** Dark mode does not persist across page refreshes. After reloading the browser, the theme toggle shows the dark mode state (sun icon) but the page renders in light mode. It takes two clicks to sync the visual state.

## Root Cause

The Zustand `themeStore` initializes `theme` state from localStorage via `getInitialTheme()`, but never calls `applyTheme()` during store creation. The `applyTheme()` function (which adds/removes the `.dark` class on `document.documentElement`) is only called inside `setTheme()` and `toggleTheme()` — user-initiated actions.

On page refresh:
1. `getInitialTheme()` reads localStorage → returns `'dark'`
2. Store initializes with `theme: 'dark'`
3. **But `applyTheme()` is never called** — the `.dark` class is missing from the DOM
4. CSS renders with light-mode variables
5. ThemeToggle shows sun icon (indicating "currently dark, click for light")

## Fix

Call `applyTheme(initialTheme)` immediately after store creation — on module load, before the first React render:

```typescript
// compute initial theme once
const initialTheme = getInitialTheme();

export const useThemeStore = create<ThemeState>((set, get) => ({
  theme: initialTheme,
  setTheme: (theme) => { applyTheme(theme); set({ theme }); },
  toggleTheme: () => {
    const next = get().theme === 'dark' ? 'light' : 'dark';
    applyTheme(next);
    set({ theme: next });
  },
}));

// Apply immediately on module load — before React mounts
applyTheme(initialTheme);
```

This ensures the `.dark` class is present on `<html>` before React's first render, preventing a flash of incorrect theme.

## Affected Files
- `ui/src/store/themeStore.ts`

## Verification
1. Set dark mode in the app
2. Hard-refresh the browser (Cmd+Shift+R)
3. The page should render in dark mode immediately — no flash, no two-click sync needed
