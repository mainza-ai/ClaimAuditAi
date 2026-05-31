export function formatCurrency(amount: number | undefined): string {
  if (amount === undefined || amount === null) return '\u2014';
  if (amount === 0) return '$0.00';
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
  }).format(amount);
}
