// DashboardScreen.tsx - Combined budget + contributions overview

import React, { useMemo } from 'react';
import { View, Text, ScrollView, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { colors, typography, spacing, borderRadius, shadows } from '../theme/pink';
import { formatCurrency } from '../utils/formatters';
import { useData } from '../context/DataContext';
import { CLASSIFICATION_META } from '../models/types';
import { computeMonthlyContributionTotal, computeTotalSpending } from '../services/budgetService';

export default function DashboardScreen() {
  const { transactions, categories, contributions, monthlyTarget } = useData();

  const totalSpent = useMemo(() => computeTotalSpending(transactions), [transactions]);
  const totalBudget = useMemo(
    () => categories.reduce((sum, c) => sum + c.monthlyLimit, 0),
    [categories]
  );
  const contributionTotal = useMemo(
    () => computeMonthlyContributionTotal(contributions),
    [contributions]
  );
  const recentTransactions = useMemo(() => transactions.slice(0, 5), [transactions]);

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Budget Health Card */}
      <View style={[styles.card, shadows.card]}>
        <Text style={styles.sectionTitle}>Budget This Month</Text>
        <Text style={styles.bigMoney}>{formatCurrency(totalSpent)}</Text>
        <Text style={styles.subtitle}>
          {totalBudget > 0
            ? `of ${formatCurrency(totalBudget)} budget`
            : 'Connect accounts to start tracking'}
        </Text>
        {totalBudget > 0 && (
          <View style={styles.progressTrack}>
            <View
              style={[
                styles.progressFill,
                {
                  width: `${Math.min((totalSpent / totalBudget) * 100, 100)}%`,
                  backgroundColor: totalSpent > totalBudget ? colors.danger : colors.pinkPrimary,
                },
              ]}
            />
          </View>
        )}
      </View>

      {/* Contribution Progress Card */}
      <View style={[styles.card, shadows.card]}>
        <Text style={styles.sectionTitle}>Retirement Contributions</Text>
        <Text style={styles.bigMoney}>
          {formatCurrency(contributionTotal)} / {formatCurrency(monthlyTarget)}
        </Text>
        <Text style={styles.subtitle}>This month's progress</Text>
        <View style={styles.progressTrack}>
          <View
            style={[
              styles.progressFill,
              {
                width: `${Math.min((contributionTotal / monthlyTarget) * 100, 100)}%`,
                backgroundColor: colors.success,
              },
            ]}
          />
        </View>
      </View>

      {/* Recent Transactions */}
      <View style={[styles.card, shadows.card]}>
        <Text style={styles.sectionTitle}>Recent Transactions</Text>
        {recentTransactions.length === 0 ? (
          <Text style={styles.emptyText}>
            Connect your bank accounts in Settings to see transactions here.
          </Text>
        ) : (
          recentTransactions.map(tx => (
            <View key={tx.id} style={styles.txRow}>
              <Ionicons
                name={CLASSIFICATION_META[tx.classification].icon as any}
                size={16}
                color={colors.pinkPrimary}
                style={{ width: 22 }}
              />
              <Text style={styles.txName} numberOfLines={1}>
                {tx.merchantName ?? tx.name}
              </Text>
              <Text style={styles.txAmount}>
                {tx.amount < 0 ? '+' : '-'}
                {formatCurrency(Math.abs(tx.amount))}
              </Text>
            </View>
          ))
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bgPrimary },
  content: { padding: spacing.lg },
  card: { backgroundColor: colors.bgCard, borderRadius: borderRadius.lg, padding: spacing.lg, marginBottom: spacing.lg },
  sectionTitle: { ...typography.headline, color: colors.textPrimary, marginBottom: spacing.md },
  bigMoney: { ...typography.money, color: colors.pinkPrimary, textAlign: 'center' },
  subtitle: { ...typography.callout, color: colors.textSecondary, textAlign: 'center', marginTop: spacing.xs },
  emptyText: { ...typography.body, color: colors.textMuted, textAlign: 'center', paddingVertical: spacing.xl },
  progressTrack: {
    height: 8,
    backgroundColor: colors.pinkLight,
    borderRadius: 4,
    overflow: 'hidden',
    marginTop: spacing.md,
  },
  progressFill: { height: 8, borderRadius: 4 },
  txRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.sm,
    borderTopWidth: 0.5,
    borderTopColor: colors.border,
  },
  txName: { ...typography.body, color: colors.textPrimary, flex: 1 },
  txAmount: { ...typography.callout, color: colors.textPrimary },
});
