// BudgetScreen.tsx
import React from 'react';
import { View, Text, ScrollView, StyleSheet } from 'react-native';
import { colors, typography, spacing, borderRadius, shadows } from '../theme/pink';
import { DEFAULT_CATEGORIES } from '../models/types';
import { formatCurrency } from '../utils/formatters';

export default function BudgetScreen() {
  const totalBudget = DEFAULT_CATEGORIES.reduce((s, c) => s + c.monthlyLimit, 0);

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Overview */}
      <View style={[styles.card, shadows.card]}>
        <Text style={styles.bigMoney}>$0</Text>
        <Text style={styles.subtitle}>of {formatCurrency(totalBudget)} budget</Text>
        <Text style={[styles.remaining, { color: colors.success }]}>
          {formatCurrency(totalBudget)} left this month
        </Text>
      </View>

      {/* Category Cards */}
      {DEFAULT_CATEGORIES.map(cat => {
        const spent = 0; // TODO: Calculate from transactions
        const ratio = cat.monthlyLimit > 0 ? spent / cat.monthlyLimit : 0;

        return (
          <View key={cat.name} style={[styles.catCard, shadows.card]}>
            <View style={styles.catHeader}>
              <Text style={styles.catName}>{cat.name}</Text>
              <Text style={styles.catAmounts}>
                {formatCurrency(spent)} / {formatCurrency(cat.monthlyLimit)}
              </Text>
            </View>
            <View style={styles.progressTrack}>
              <View style={[styles.progressFill, {
                width: `${Math.min(ratio * 100, 100)}%`,
                backgroundColor: `#${cat.colorHex}`,
              }]} />
            </View>
          </View>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bgPrimary },
  content: { padding: spacing.lg },
  card: { backgroundColor: colors.bgCard, borderRadius: borderRadius.lg, padding: spacing.lg, marginBottom: spacing.lg, alignItems: 'center' },
  bigMoney: { ...typography.money, color: colors.pinkPrimary },
  subtitle: { ...typography.callout, color: colors.textMuted, marginTop: spacing.xs },
  remaining: { ...typography.callout, marginTop: spacing.sm },
  catCard: { backgroundColor: colors.bgCard, borderRadius: borderRadius.md, padding: spacing.md, marginBottom: spacing.sm },
  catHeader: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: spacing.sm },
  catName: { ...typography.body, color: colors.textPrimary },
  catAmounts: { ...typography.callout, color: colors.textSecondary },
  progressTrack: { height: 6, backgroundColor: colors.pinkLight, borderRadius: 3, overflow: 'hidden' },
  progressFill: { height: 6, borderRadius: 3 },
});
