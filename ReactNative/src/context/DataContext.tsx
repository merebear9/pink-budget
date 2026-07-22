import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { Account, AccountType, BudgetCategory, Contribution, Transaction } from '../models/types';
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
  monthlyTarget: number;
  plaidEnvironment: PlaidEnvironment;
  isSyncing: boolean;
  setMonthlyTarget: (value: number) => Promise<void>;
  setPlaidEnvironment: (value: PlaidEnvironment) => Promise<void>;
  addAccountsFromPlaid: (plaidAccounts: PlaidAccount[], accessToken: string) => Promise<void>;
  syncAllAccounts: () => Promise<void>;
  addManualContribution: (contribution: Omit<Contribution, 'id' | 'source'>) => Promise<void>;
}

const DataContext = createContext<DataContextValue | null>(null);

export function DataProvider({ children }: { children: React.ReactNode }) {
  const [isReady, setIsReady] = useState(false);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [categories, setCategories] = useState<BudgetCategory[]>([]);
  const [contributions, setContributions] = useState<Contribution[]>([]);
  const [monthlyTarget, setMonthlyTargetState] = useState(DEFAULT_MONTHLY_TARGET);
  const [plaidEnvironment, setPlaidEnvironmentState] = useState<PlaidEnvironment>('sandbox');
  const [isSyncing, setIsSyncing] = useState(false);

  const refreshAccounts = useCallback(async () => setAccounts(await db.getAccounts()), []);
  const refreshTransactions = useCallback(async () => setTransactions(await db.getTransactions()), []);
  const refreshCategories = useCallback(async () => setCategories(await db.getBudgetCategories()), []);
  const refreshContributions = useCallback(async () => setContributions(await db.getContributions()), []);

  useEffect(() => {
    (async () => {
      await Promise.all([
        refreshAccounts(),
        refreshTransactions(),
        refreshCategories(),
        refreshContributions(),
      ]);

      const storedTarget = await db.getSetting('monthlyContributionTarget');
      if (storedTarget) setMonthlyTargetState(parseFloat(storedTarget));

      const storedEnv = await db.getSetting('plaidEnvironment');
      if (storedEnv === 'sandbox' || storedEnv === 'development' || storedEnv === 'production') {
        setPlaidEnvironmentState(storedEnv);
      }

      setIsReady(true);
    })();
  }, [refreshAccounts, refreshTransactions, refreshCategories, refreshContributions]);

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

  const value = useMemo<DataContextValue>(
    () => ({
      isReady,
      accounts,
      transactions,
      categories,
      contributions,
      monthlyTarget,
      plaidEnvironment,
      isSyncing,
      setMonthlyTarget,
      setPlaidEnvironment,
      addAccountsFromPlaid,
      syncAllAccounts,
      addManualContribution,
    }),
    [
      isReady,
      accounts,
      transactions,
      categories,
      contributions,
      monthlyTarget,
      plaidEnvironment,
      isSyncing,
      setMonthlyTarget,
      setPlaidEnvironment,
      addAccountsFromPlaid,
      syncAllAccounts,
      addManualContribution,
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
