// BudgetScreen.tsx
import React, { useMemo } from 'react';
import { View, Text, ScrollView, StyleSheet } from 'react-native';
import { colors, typography, spacing, borderRadius, shadows } from '../theme/pink';
import { formatCurrency } from '../utils/formatters';
import { useData } from '../context/DataContext';
import { computeCategorySpending, computeTotalSpending } from '../services/budgetService';

export default function BudgetScreen() {
  const { transactions, categories } = useData();

  const totalBudget = useMemo(
    () => categories.reduce((s, c) => s + c.monthlyLimit, 0),
    [categories]
  );
  const totalSpent = useMemo(() => computeTotalSpending(transactions), [transactions]);
  const categorySpending = useMemo(
    () => computeCategorySpending(transactions, categories),
    [transactions, categories]
  );
  const remaining = totalBudget - totalSpent;

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Overview */}
      <View style={[styles.card, shadows.card]}>
        <Text style={styles.bigMoney}>{formatCurrency(totalSpent)}</Text>
        <Text style={styles.subtitle}>of {formatCurrency(totalBudget)} budget</Text>
        <Text style={[styles.remaining, { color: remaining >= 0 ? colors.success : colors.danger }]}>
          {remaining >= 0
            ? `${formatCurrency(remaining)} left this month`
            : `${formatCurrency(-remaining)} over budget`}
        </Text>
      </View>

      {/* Category Cards */}
      {categorySpending.map(({ category, spent }) => {
        const ratio = category.monthlyLimit > 0 ? spent / category.monthlyLimit : 0;

        return (
          <View key={category.id} style={[styles.catCard, shadows.card]}>
            <View style={styles.catHeader}>
              <Text style={styles.catName}>{category.name}</Text>
              <Text style={styles.catAmounts}>
                {formatCurrency(spent)} / {formatCurrency(category.monthlyLimit)}
              </Text>
            </View>
            <View style={styles.progressTrack}>
              <View
                style={[
                  styles.progressFill,
                  {
                    width: `${Math.min(ratio * 100, 100)}%`,
                    backgroundColor: ratio > 1 ? colors.danger : `#${category.colorHex}`,
                  },
                ]}
              />
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
