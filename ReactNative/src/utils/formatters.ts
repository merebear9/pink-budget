// Currency formatting
export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(amount);
}

export function formatCompactCurrency(amount: number): string {
  if (Math.abs(amount) >= 1000) {
    return `$${(amount / 1000).toFixed(1)}K`;
  }
  return formatCurrency(amount);
}

// Date formatting
export function formatMonthYear(date: Date): string {
  return date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
}

export function formatShortDate(date: Date): string {
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export function getMonthName(month: number): string {
  const date = new Date(2026, month - 1, 1);
  return date.toLocaleDateString('en-US', { month: 'long' });
}

export function getShortMonthName(month: number): string {
  const date = new Date(2026, month - 1, 1);
  return date.toLocaleDateString('en-US', { month: 'short' });
}
