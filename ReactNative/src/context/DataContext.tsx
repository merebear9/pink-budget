import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import {
  Account,
  AccountType,
  BudgetCategory,
  ContributionLabel,
  Contribution,
  RecurringContribution,
  Transaction,
  TransactionClassification,
} from '../models/types';
import * as db from '../database';
import { syncAccountTransactions } from '../services/transactionService';
import { PlaidAccount } from '../services/plaidService';

export type PlaidEnvironment = 'sandbox' | 'development' | 'production';

const DEFAULT_MONTHLY_TARGET = 3500;

interface DataContextValue {
  isReady: boolean;
  accounts: Account[];
  transactions: Transaction[];
  categories: BudgetCategory[];
  contributions: Contribution[];
  recurringContributions: RecurringContribution[];
  monthlyTarget: number;
  plaidEnvironment: PlaidEnvironment;
  isSyncing: boolean;
  setMonthlyTarget: (value: number) => Promise<void>;
  setPlaidEnvironment: (value: PlaidEnvironment) => Promise<void>;
  addAccountsFromPlaid: (plaidAccounts: PlaidAccount[], accessToken: string) => Promise<void>;
  syncAllAccounts: () => Promise<void>;
  addManualContribution: (contribution: Omit<Contribution, 'id' | 'source'>) => Promise<void>;
  reclassifyTransaction: (
    transactionId: string,
    classification: TransactionClassification,
    categoryName: string
  ) => Promise<void>;
  updateAccountRetirementInfo: (
    accountId: string,
    isRetirementAccount: boolean,
    contributionLabel: ContributionLabel
  ) => Promise<void>;
  addRecurringContribution: (recurring: Omit<RecurringContribution, 'id'>) => Promise<void>;
  setRecurringContributionActive: (id: string, isActive: boolean) => Promise<void>;
  deleteRecurringContribution: (id: string) => Promise<void>;
}

const DataContext = createContext<DataContextValue | null>(null);

export function DataProvider({ children }: { children: React.ReactNode }) {
  const [isReady, setIsReady] = useState(false);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [categories, setCategories] = useState<BudgetCategory[]>([]);
  const [contributions, setContributions] = useState<Contribution[]>([]);
  const [recurringContributions, setRecurringContributions] = useState<RecurringContribution[]>([]);
  const [monthlyTarget, setMonthlyTargetState] = useState(DEFAULT_MONTHLY_TARGET);
  const [plaidEnvironment, setPlaidEnvironmentState] = useState<PlaidEnvironment>('sandbox');
  const [isSyncing, setIsSyncing] = useState(false);

  const refreshAccounts = useCallback(async () => setAccounts(await db.getAccounts()), []);
  const refreshTransactions = useCallback(async () => setTransactions(await db.getTransactions()), []);
  const refreshCategories = useCallback(async () => setCategories(await db.getBudgetCategories()), []);
  const refreshContributions = useCallback(async () => setContributions(await db.getContributions()), []);
  const refreshRecurringContributions = useCallback(
    async () => setRecurringContributions(await db.getRecurringContributions()),
    []
  );

  useEffect(() => {
    (async () => {
      await Promise.all([
        refreshAccounts(),
        refreshTransactions(),
        refreshCategories(),
        refreshContributions(),
        refreshRecurringContributions(),
      ]);

      const storedTarget = await db.getSetting('monthlyContributionTarget');
      if (storedTarget) setMonthlyTargetState(parseFloat(storedTarget));

      const storedEnv = await db.getSetting('plaidEnvironment');
      if (storedEnv === 'sandbox' || storedEnv === 'development' || storedEnv === 'production') {
        setPlaidEnvironmentState(storedEnv);
      }

      // Add this month's amount for any active recurring contribution
      // (e.g. an employer 401(k) Plaid can't see) that hasn't been added yet.
      const dueRecurring = await db.getRecurringContributions();
      const now = new Date();
      let addedAny = false;
      for (const recurring of dueRecurring) {
        if (!recurring.isActive) continue;
        const alreadyAdded = await db.hasContributionForRecurringInMonth(
          recurring.id,
          now.getFullYear(),
          now.getMonth() + 1
        );
        if (alreadyAdded) continue;

        await db.insertContribution({
          date: now.toISOString(),
          amount: recurring.amount,
          label: recurring.label,
          source: 'recurring',
          notes: recurring.note,
          linkedTransactionId: null,
          recurringContributionId: recurring.id,
        });
        addedAny = true;
      }
      if (addedAny) await refreshContributions();

      setIsReady(true);
    })();
  }, [
    refreshAccounts,
    refreshTransactions,
    refreshCategories,
    refreshContributions,
    refreshRecurringContributions,
  ]);

  const setMonthlyTarget = useCallback(async (value: number) => {
    setMonthlyTargetState(value);
    await db.setSetting('monthlyContributionTarget', String(value));
  }, []);

  const setPlaidEnvironment = useCallback(async (value: PlaidEnvironment) => {
    setPlaidEnvironmentState(value);
    await db.setSetting('plaidEnvironment', value);
  }, []);

  const addAccountsFromPlaid = useCallback(
    async (plaidAccounts: PlaidAccount[], accessToken: string) => {
      const created: Account[] = [];
      for (const pa of plaidAccounts) {
        const account = await db.insertAccount({
          plaidAccountId: pa.account_id,
          plaidAccessToken: accessToken,
          institutionName: pa.official_name ?? pa.name,
          accountName: pa.name,
          accountType: mapPlaidAccountType(pa.type),
          currentBalance: pa.balances.current ?? 0,
          lastSynced: null,
          isActive: true,
          isRetirementAccount: false,
          contributionLabel: 'Other',
        });
        created.push(account);
      }
      await refreshAccounts();

      setIsSyncing(true);
      try {
        for (const account of created) {
          await syncAccountTransactions(account, categories);
        }
        await Promise.all([refreshTransactions(), refreshAccounts(), refreshContributions()]);
      } finally {
        setIsSyncing(false);
      }
    },
    [categories, refreshAccounts, refreshTransactions, refreshContributions]
  );

  const syncAllAccounts = useCallback(async () => {
    setIsSyncing(true);
    try {
      for (const account of accounts) {
        await syncAccountTransactions(account, categories);
      }
      await Promise.all([refreshTransactions(), refreshAccounts(), refreshContributions()]);
    } finally {
      setIsSyncing(false);
    }
  }, [accounts, categories, refreshTransactions, refreshAccounts, refreshContributions]);

  const addManualContribution = useCallback(
    async (contribution: Omit<Contribution, 'id' | 'source'>) => {
      await db.insertContribution({ ...contribution, source: 'manual' });
      await refreshContributions();
    },
    [refreshContributions]
  );

  const reclassifyTransaction = useCallback(
    async (transactionId: string, classification: TransactionClassification, categoryName: string) => {
      await db.reclassifyTransaction(transactionId, classification, categoryName);
      await refreshTransactions();
    },
    [refreshTransactions]
  );

  const updateAccountRetirementInfo = useCallback(
    async (accountId: string, isRetirementAccount: boolean, contributionLabel: ContributionLabel) => {
      await db.setAccountRetirementInfo(accountId, isRetirementAccount, contributionLabel);
      await refreshAccounts();
    },
    [refreshAccounts]
  );

  const addRecurringContribution = useCallback(
    async (recurring: Omit<RecurringContribution, 'id'>) => {
      await db.insertRecurringContribution(recurring);
      await refreshRecurringContributions();
    },
    [refreshRecurringContributions]
  );

  const setRecurringContributionActive = useCallback(
    async (id: string, isActive: boolean) => {
      await db.setRecurringContributionActive(id, isActive);
      await refreshRecurringContributions();
    },
    [refreshRecurringContributions]
  );

  const deleteRecurringContribution = useCallback(
    async (id: string) => {
      await db.deleteRecurringContribution(id);
      await refreshRecurringContributions();
    },
    [refreshRecurringContributions]
  );

  const value = useMemo<DataContextValue>(
    () => ({
      isReady,
      accounts,
      transactions,
      categories,
      contributions,
      recurringContributions,
      monthlyTarget,
      plaidEnvironment,
      isSyncing,
      setMonthlyTarget,
      setPlaidEnvironment,
      addAccountsFromPlaid,
      syncAllAccounts,
      addManualContribution,
      reclassifyTransaction,
      updateAccountRetirementInfo,
      addRecurringContribution,
      setRecurringContributionActive,
      deleteRecurringContribution,
    }),
    [
      isReady,
      accounts,
      transactions,
      categories,
      contributions,
      recurringContributions,
      monthlyTarget,
      plaidEnvironment,
      isSyncing,
      setMonthlyTarget,
      setPlaidEnvironment,
      addAccountsFromPlaid,
      syncAllAccounts,
      addManualContribution,
      reclassifyTransaction,
      updateAccountRetirementInfo,
      addRecurringContribution,
      setRecurringContributionActive,
      deleteRecurringContribution,
    ]
  );

  return <DataContext.Provider value={value}>{children}</DataContext.Provider>;
}

export function useData(): DataContextValue {
  const ctx = useContext(DataContext);
  if (!ctx) throw new Error('useData must be used within a DataProvider');
  return ctx;
}

function mapPlaidAccountType(plaidType: string): AccountType {
  switch (plaidType) {
    case 'depository':
      return 'depository';
    case 'credit':
      return 'credit';
    case 'loan':
      return 'loan';
    case 'investment':
      return 'investment';
    default:
      return 'other';
  }
}
