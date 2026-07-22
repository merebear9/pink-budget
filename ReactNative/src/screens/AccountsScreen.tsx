// AccountsScreen.tsx
// Opens Plaid Link via react-native-plaid-link-sdk, exchanges the resulting
// public token for an access token through the backend, fetches balances,
// and creates local Account records. Reached from Settings > Manage Accounts.

import React, { useCallback, useState } from 'react';
import { View, Text, ScrollView, StyleSheet, TouchableOpacity, ActivityIndicator } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import {
  createPlaidLinkSession,
  LinkExit,
  LinkSuccess,
} from 'react-native-plaid-link-sdk';
import { colors, typography, spacing, borderRadius, shadows } from '../theme/pink';
import { formatCurrency } from '../utils/formatters';
import { useData } from '../context/DataContext';
import { createLinkToken, exchangePublicToken, fetchBalances } from '../services/plaidService';

const ACCOUNT_ICONS: Record<string, keyof typeof Ionicons.glyphMap> = {
  depository: 'cash-outline',
  credit: 'card-outline',
  investment: 'trending-up-outline',
  retirement: 'business-outline',
  loan: 'document-text-outline',
  other: 'ellipsis-horizontal-circle-outline',
};

type LinkState = 'idle' | 'connecting' | 'finishing';

export default function AccountsScreen() {
  const { accounts, addAccountsFromPlaid } = useData();
  const [linkState, setLinkState] = useState<LinkState>('idle');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleLinkSuccess = useCallback(
    async (publicToken: string) => {
      setLinkState('finishing');
      setErrorMessage(null);
      try {
        const accessToken = await exchangePublicToken(publicToken);
        const plaidAccounts = await fetchBalances(accessToken);
        await addAccountsFromPlaid(plaidAccounts, accessToken);
      } catch (error) {
        setErrorMessage(
          error instanceof Error ? error.message : "Connected, but couldn't finish setup."
        );
      } finally {
        setLinkState('idle');
      }
    },
    [addAccountsFromPlaid]
  );

  const handleConnectPress = useCallback(async () => {
    setLinkState('connecting');
    setErrorMessage(null);
    try {
      const linkToken = await createLinkToken();
      const session = await createPlaidLinkSession({
        token: linkToken,
        onSuccess: (success: LinkSuccess) => {
          handleLinkSuccess(success.publicToken);
        },
        onExit: (exit: LinkExit) => {
          if (exit.error) {
            setErrorMessage(exit.error.displayMessage ?? exit.error.errorMessage);
          }
          setLinkState('idle');
        },
        onEvent: () => {},
      });
      await session.open();
      setLinkState('idle');
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Could not start Plaid Link.');
      setLinkState('idle');
    }
  }, [handleLinkSuccess]);

  const isBusy = linkState !== 'idle';

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {accounts.length === 0 ? (
        <View style={styles.empty}>
          <Ionicons name="business-outline" size={48} color={colors.pinkSoft} />
          <Text style={styles.emptyTitle}>No accounts connected</Text>
          <Text style={styles.emptyBody}>
            Link your bank, retirement, and credit card accounts through Plaid to
            auto-import transactions.
          </Text>
        </View>
      ) : (
        accounts.map(account => (
          <View key={account.id} style={[styles.card, shadows.card]}>
            <View style={styles.cardHeader}>
              <Ionicons
                name={ACCOUNT_ICONS[account.accountType]}
                size={22}
                color={colors.pinkPrimary}
                style={{ width: 26 }}
              />
              <View style={{ flex: 1 }}>
                <Text style={styles.accountName}>{account.accountName}</Text>
                <Text style={styles.institutionName}>{account.institutionName}</Text>
              </View>
              <Text style={styles.balance}>{formatCurrency(account.currentBalance)}</Text>
            </View>
            {account.isRetirementAccount && (
              <View style={styles.retirementBadgeRow}>
                <Ionicons name="checkmark-circle" size={14} color={colors.success} />
                <Text style={styles.retirementBadgeText}>
                  Tracking as {account.contributionLabel}
                </Text>
              </View>
            )}
            {account.lastSynced && (
              <Text style={styles.lastSynced}>
                Last synced {new Date(account.lastSynced).toLocaleString()}
              </Text>
            )}
          </View>
        ))
      )}

      {errorMessage && (
        <View style={styles.errorBox}>
          <Text style={styles.errorText}>{errorMessage}</Text>
        </View>
      )}

      <TouchableOpacity
        style={[styles.connectButton, isBusy && styles.connectButtonDisabled]}
        onPress={handleConnectPress}
        disabled={isBusy}
      >
        {isBusy ? (
          <ActivityIndicator color="#fff" />
        ) : (
          <Ionicons name="add-circle" size={20} color="#fff" />
        )}
        <Text style={styles.connectButtonText}>
          {linkState === 'connecting'
            ? 'Opening Plaid…'
            : linkState === 'finishing'
              ? 'Finishing setup…'
              : 'Connect Account'}
        </Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bgPrimary },
  content: { padding: spacing.lg },
  empty: { alignItems: 'center', paddingVertical: 40, paddingHorizontal: 24 },
  emptyTitle: { ...typography.title2, color: colors.textPrimary, marginTop: spacing.lg },
  emptyBody: {
    ...typography.body,
    color: colors.textSecondary,
    textAlign: 'center',
    marginTop: spacing.sm,
  },
  card: {
    backgroundColor: colors.bgCard,
    borderRadius: borderRadius.lg,
    padding: spacing.lg,
    marginBottom: spacing.md,
  },
  cardHeader: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  accountName: { ...typography.headline, color: colors.textPrimary },
  institutionName: { ...typography.caption, color: colors.textMuted },
  balance: { ...typography.moneySmall, color: colors.textPrimary },
  retirementBadgeRow: { flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: spacing.sm },
  retirementBadgeText: { ...typography.caption, color: colors.success },
  lastSynced: { ...typography.caption, color: colors.textMuted, marginTop: spacing.xs },
  errorBox: {
    backgroundColor: colors.danger + '15',
    borderRadius: borderRadius.md,
    padding: spacing.md,
    marginBottom: spacing.md,
  },
  errorText: { ...typography.callout, color: colors.danger },
  connectButton: {
    backgroundColor: colors.pinkPrimary,
    borderRadius: borderRadius.md,
    padding: spacing.md,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: spacing.sm,
    marginTop: spacing.sm,
  },
  connectButtonDisabled: { opacity: 0.7 },
  connectButtonText: { ...typography.headline, color: '#fff' },
});
