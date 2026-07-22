// ── Transaction Classification ──

export type TransactionClassification =
  | 'spending'       // Counts toward budget
  | 'transfer'       // CC payments, internal moves -- EXCLUDED
  | 'contribution'   // Retirement/investment -- tracked separately
  | 'income'         // Paychecks, deposits
  | 'excluded';      // Fees, interest, other

export const CLASSIFICATION_META: Record<TransactionClassification, {
  displayName: string;
  icon: string;
  countsTowardBudget: boolean;
}> = {
  spending: { displayName: 'Spending', icon: 'cart', countsTowardBudget: true },
  transfer: { displayName: 'Transfer', icon: 'swap-horizontal', countsTowardBudget: false },
  contribution: { displayName: 'Investment', icon: 'arrow-up-circle', countsTowardBudget: false },
  income: { displayName: 'Income', icon: 'arrow-down-circle', countsTowardBudget: false },
  excluded: { displayName: 'Other', icon: 'minus-circle', countsTowardBudget: false },
};

// ── Account ──

export type AccountType = 'depository' | 'credit' | 'investment' | 'retirement' | 'loan' | 'other';
export type ContributionLabel = 'TSP' | '401(k)' | 'Roth IRA' | 'Other';

export interface Account {
  id: string;
  plaidAccountId: string;
  plaidAccessToken: string;
  institutionName: string;
  accountName: string;
  accountType: AccountType;
  currentBalance: number;
  lastSynced: string | null;
  isActive: boolean;
  isRetirementAccount: boolean;
  contributionLabel: ContributionLabel;
}

// ── Transaction ──

export interface Transaction {
  id: string;
  plaidTransactionId: string | null;
  date: string;                           // ISO date
  amount: number;                         // Positive = expense, Negative = income
  merchantName: string | null;
  name: string;
  categoryName: string;
  plaidCategory: string | null;
  isPending: boolean;
  classification: TransactionClassification;
  isManuallyClassified: boolean;
  notes: string | null;
  accountId: string | null;
}

// ── Budget Category ──

export interface BudgetCategory {
  id: string;
  name: string;
  icon: string;                           // Icon name (Ionicons)
  monthlyLimit: number;
  colorHex: string;
  sortOrder: number;
  isActive: boolean;
  matchKeywords: string[];
  plaidCategories: string[];
}

// ── Contribution ──

export interface Contribution {
  id: string;
  date: string;
  amount: number;
  label: ContributionLabel;
  source: 'plaid' | 'manual';
  notes: string | null;
  linkedTransactionId: string | null;
}

// ── Summaries ──

export interface MonthlyContributionSummary {
  month: number;
  year: number;
  tsp: number;
  k401: number;
  roth: number;
  other: number;
  total: number;
}

export interface AnnualContributionSummary {
  year: number;
  months: MonthlyContributionSummary[];
  monthlyTarget: number;
  totalContributed: number;
  annualTarget: number;
  percentOfTarget: number;
  averageMonthly: number;
  remainingToTarget: number;
  tspTotal: number;
  k401Total: number;
  rothTotal: number;
  otherTotal: number;
}

// ── Default Categories ──

export const DEFAULT_CATEGORIES: Omit<BudgetCategory, 'id'>[] = [
  {
    name: 'Rent',
    icon: 'home',
    monthlyLimit: 800,
    colorHex: 'E91E8C',
    sortOrder: 0,
    isActive: true,
    matchKeywords: ['rent', 'lease', 'foundry'],
    plaidCategories: ['RENT'],
  },
  {
    name: 'Groceries',
    icon: 'cart',
    monthlyLimit: 300,
    colorHex: '10B981',
    sortOrder: 1,
    isActive: true,
    matchKeywords: ['walmart', 'kroger', 'aldi', 'meijer', 'target', 'grocery'],
    plaidCategories: ['FOOD_AND_DRINK_GROCERIES'],
  },
  {
    name: 'Gas & Transport',
    icon: 'car',
    monthlyLimit: 200,
    colorHex: '6366F1',
    sortOrder: 2,
    isActive: true,
    matchKeywords: ['shell', 'bp', 'speedway', 'marathon', 'gas', 'fuel'],
    plaidCategories: ['TRANSPORTATION_GAS'],
  },
  {
    name: 'Dining Out',
    icon: 'restaurant',
    monthlyLimit: 150,
    colorHex: 'F59E0B',
    sortOrder: 3,
    isActive: true,
    matchKeywords: ['restaurant', 'starbucks', 'chipotle', 'mcdonald'],
    plaidCategories: ['FOOD_AND_DRINK_RESTAURANT'],
  },
  {
    name: 'Subscriptions',
    icon: 'tv',
    monthlyLimit: 50,
    colorHex: '8B5CF6',
    sortOrder: 4,
    isActive: true,
    matchKeywords: ['netflix', 'spotify', 'apple', 'youtube', 'hulu', 'adobe'],
    plaidCategories: ['GENERAL_MERCHANDISE_SUBSCRIPTION'],
  },
  {
    name: 'Cat Care',
    icon: 'paw',
    monthlyLimit: 100,
    colorHex: 'EC4899',
    sortOrder: 5,
    isActive: true,
    matchKeywords: ['petco', 'petsmart', 'chewy', 'vet', 'veterinary'],
    plaidCategories: ['GENERAL_MERCHANDISE_PET_SUPPLIES'],
  },
  {
    name: 'Personal',
    icon: 'bag-handle',
    monthlyLimit: 150,
    colorHex: '06B6D4',
    sortOrder: 6,
    isActive: true,
    matchKeywords: [],
    plaidCategories: ['GENERAL_MERCHANDISE'],
  },
  {
    name: 'Misc',
    icon: 'ellipsis-horizontal-circle',
    monthlyLimit: 100,
    colorHex: '9CA3AF',
    sortOrder: 7,
    isActive: true,
    matchKeywords: [],
    plaidCategories: [],
  },
];
