// AccountsScreen.tsx
// Opens Plaid Link via react-native-plaid-link-sdk, exchanges the resulting
// public token for an access token through the backend, fetches balances,
// and creates local Account records. Reached from Settings > Manage Accounts.
// Tapping a connected account lets you mark it as a retirement account and
// pick which contribution bucket (TSP / 401(k) / Roth IRA / Other) it feeds.

import React, { useCallback, useState } from 'react';
import { View, Text, ScrollView, StyleSheet, TouchableOpacity, ActivityIndicator, Modal, Switch } from 'react-native';
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
import { Account, CONTRIBUTION_LABELS, ContributionLabel } from '../models/types';

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
  const { accounts, addAccountsFromPlaid, updateAccountRetirementInfo } = useData();
  const [linkState, setLinkState] = useState<LinkState>('idle');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [editingAccount, setEditingAccount] = useState<Account | null>(null);

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
          <TouchableOpacity
            key={account.id}
            style={[styles.card, shadows.card]}
            onPress={() => setEditingAccount(account)}
          >
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
              <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
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
          </TouchableOpacity>
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

      <AccountEditModal
        account={editingAccount}
        onClose={() => setEditingAccount(null)}
        onSave={updateAccountRetirementInfo}
      />
    </ScrollView>
  );
}

function AccountEditModal({
  account,
  onClose,
  onSave,
}: {
  account: Account | null;
  onClose: () => void;
  onSave: (accountId: string, isRetirementAccount: boolean, contributionLabel: ContributionLabel) => Promise<void>;
}) {
  const [isRetirement, setIsRetirement] = useState(account?.isRetirementAccount ?? false);
  const [label, setLabel] = useState<ContributionLabel>(account?.contributionLabel ?? 'Other');
  const [isSaving, setIsSaving] = useState(false);

  // Reset local edit state whenever a different account is opened.
  React.useEffect(() => {
    if (account) {
      setIsRetirement(account.isRetirementAccount);
      setLabel(account.contributionLabel);
    }
  }, [account]);

  if (!account) return null;

  const handleSave = async () => {
    setIsSaving(true);
    try {
      await onSave(account.id, isRetirement, label);
      onClose();
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <Modal visible transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.modalOverlay}>
        <View style={[styles.modalCard, shadows.card]}>
          <Text style={styles.modalTitle}>{account.accountName}</Text>
          <Text style={styles.modalSubtitle}>{account.institutionName}</Text>

          <View style={styles.switchRow}>
            <Text style={styles.switchLabel}>Is Retirement Account</Text>
            <Switch
              value={isRetirement}
              onValueChange={setIsRetirement}
              trackColor={{ true: colors.pinkPrimary }}
            />
          </View>

          {isRetirement && (
            <>
              <Text style={styles.modalLabel}>Contribution Label</Text>
              <View style={styles.chipWrap}>
                {CONTRIBUTION_LABELS.map(l => (
                  <TouchableOpacity
                    key={l}
                    style={[styles.labelChip, label === l && styles.labelChipActive]}
                    onPress={() => setLabel(l)}
                  >
                    <Text style={[styles.labelChipText, label === l && styles.labelChipTextActive]}>
                      {l}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            </>
          )}

          <View style={styles.modalButtonRow}>
            <TouchableOpacity style={[styles.modalButton, styles.modalCancelButton]} onPress={onClose}>
              <Text style={styles.modalCancelText}>Cancel</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.modalButton, styles.modalSaveButton, isSaving && { opacity: 0.6 }]}
              onPress={handleSave}
              disabled={isSaving}
            >
              <Text style={styles.modalSaveText}>{isSaving ? 'Saving…' : 'Save'}</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
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
  modalOverlay: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(0,0,0,0.4)' },
  modalCard: {
    backgroundColor: colors.bgCard,
    borderTopLeftRadius: borderRadius.lg,
    borderTopRightRadius: borderRadius.lg,
    padding: spacing.xl,
  },
  modalTitle: { ...typography.title2, color: colors.textPrimary },
  modalSubtitle: { ...typography.caption, color: colors.textMuted, marginBottom: spacing.lg },
  switchRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.lg,
  },
  switchLabel: { ...typography.body, color: colors.textPrimary },
  modalLabel: { ...typography.callout, color: colors.textSecondary, marginBottom: spacing.sm },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginBottom: spacing.lg },
  labelChip: { backgroundColor: colors.pinkLight, borderRadius: 16, paddingHorizontal: 14, paddingVertical: 8 },
  labelChipActive: { backgroundColor: colors.pinkPrimary },
  labelChipText: { ...typography.callout, color: colors.pinkPrimary },
  labelChipTextActive: { color: '#fff' },
  modalButtonRow: { flexDirection: 'row', gap: spacing.md, marginTop: spacing.sm },
  modalButton: { flex: 1, borderRadius: borderRadius.md, padding: spacing.md, alignItems: 'center' },
  modalCancelButton: { backgroundColor: colors.pinkLight },
  modalCancelText: { ...typography.headline, color: colors.pinkPrimary },
  modalSaveButton: { backgroundColor: colors.pinkPrimary },
  modalSaveText: { ...typography.headline, color: '#fff' },
});
