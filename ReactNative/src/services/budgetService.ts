import { BudgetCategory, Contribution, Transaction } from '../models/types';
import { isSameMonth } from '../utils/formatters';

export interface CategorySpend {
  category: BudgetCategory;
  spent: number;
}

export function computeCategorySpending(
  transactions: Transaction[],
  categories: BudgetCategory[],
  reference: Date = new Date()
): CategorySpend[] {
  return categories.map(category => {
    const spent = transactions
      .filter(tx => tx.classification === 'spending')
      .filter(tx => tx.categoryName === category.name)
      .filter(tx => isSameMonth(tx.date, reference))
      .reduce((sum, tx) => sum + Math.abs(tx.amount), 0);
    return { category, spent };
  });
}

export function computeTotalSpending(transactions: Transaction[], reference: Date = new Date()): number {
  return transactions
    .filter(tx => tx.classification === 'spending')
    .filter(tx => isSameMonth(tx.date, reference))
    .reduce((sum, tx) => sum + Math.abs(tx.amount), 0);
}

export function computeMonthlyContributionTotal(
  contributions: Contribution[],
  reference: Date = new Date()
): number {
  return contributions
    .filter(c => isSameMonth(c.date, reference))
    .reduce((sum, c) => sum + c.amount, 0);
}
