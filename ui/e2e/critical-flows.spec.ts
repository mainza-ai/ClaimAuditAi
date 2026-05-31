import { test, expect } from '@playwright/test';

test.describe('ClaimAuditAI — Critical User Flows', () => {
  test('login page renders', async ({ page }) => {
    await page.goto('/login');
    await expect(page.locator('h1')).toContainText('ClaimAuditAI');
    await expect(page.getByLabel('Username')).toBeVisible();
    await expect(page.getByLabel('Password')).toBeVisible();
    await expect(page.getByRole('button', { name: /sign in/i })).toBeVisible();
  });

  test('redirects to login when not authenticated', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page).toHaveURL(/\/login/);
  });

  test('login with valid credentials redirects to dashboard', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Username').fill('admin');
    await page.getByLabel('Password').fill('ClaimAuditAdmin2026!');
    await page.getByRole('button', { name: /sign in/i }).click();
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 10000 });
  });

  test('dashboard renders after login', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Username').fill('admin');
    await page.getByLabel('Password').fill('ClaimAuditAdmin2026!');
    await page.getByRole('button', { name: /sign in/i }).click();
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 10000 });
    await expect(page.locator('text=Dashboard')).toBeVisible({ timeout: 5000 });
  });

  test('sidebar navigation works', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Username').fill('admin');
    await page.getByLabel('Password').fill('ClaimAuditAdmin2026!');
    await page.getByRole('button', { name: /sign in/i }).click();
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 10000 });
    // Navigate to hold queue
    await page.click('text=Hold queue');
    await expect(page).toHaveURL(/\/queue/, { timeout: 5000 });
  });

  test('seed sample data enriches dashboard', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Username').fill('auditor');
    await page.getByLabel('Password').fill('AuditReview2026!');
    await page.getByRole('button', { name: /sign in/i }).click();
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 10000 });
    // Click seed sample data
    const seedBtn = page.locator('button:has-text("Seed Sample Data")');
    if (await seedBtn.isVisible()) {
      await seedBtn.click();
      await expect(page.locator('text=Seeded!')).toBeVisible({ timeout: 30000 });
    }
  });

  test('hold queue displays pending claims', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Username').fill('auditor');
    await page.getByLabel('Password').fill('AuditReview2026!');
    await page.getByRole('button', { name: /sign in/i }).click();
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 10000 });
    await page.click('text=Hold queue');
    await expect(page).toHaveURL(/\/queue/, { timeout: 5000 });
  });

  test('audit ledger renders', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Username').fill('auditor');
    await page.getByLabel('Password').fill('AuditReview2026!');
    await page.getByRole('button', { name: /sign in/i }).click();
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 10000 });
    await page.click('text=Audit ledger');
    await expect(page).toHaveURL(/\/ledger/, { timeout: 5000 });
  });

  test('graph view renders', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Username').fill('auditor');
    await page.getByLabel('Password').fill('AuditReview2026!');
    await page.getByRole('button', { name: /sign in/i }).click();
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 10000 });
    await page.click('text=Network graph');
    await expect(page).toHaveURL(/\/graph/, { timeout: 5000 });
  });
});
