// DashboardScreen.tsx - Combined budget + contributions overview
// Full implementation mirrors the iOS DashboardView.swift

import React from 'react';
import { View, Text, ScrollView, StyleSheet } from 'react-native';
import { colors, typography, spacing, borderRadius, shadows } from '../theme/pink';

export default function DashboardScreen() {
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Budget Health Card */}
      <View style={[styles.card, shadows.card]}>
        <Text style={styles.sectionTitle}>Budget This Month</Text>
        <Text style={styles.bigMoney}>$0</Text>
        <Text style={styles.subtitle}>Connect accounts to start tracking</Text>
        {/* Progress bar goes here */}
      </View>

      {/* Contribution Progress Card */}
      <View style={[styles.card, shadows.card]}>
        <Text style={styles.sectionTitle}>Retirement Contributions</Text>
        <Text style={styles.bigMoney}>$0 / $3,500</Text>
        <Text style={styles.subtitle}>This month's progress</Text>
        {/* Progress ring goes here */}
      </View>

      {/* Recent Transactions */}
      <View style={[styles.card, shadows.card]}>
        <Text style={styles.sectionTitle}>Recent Transactions</Text>
        <Text style={styles.emptyText}>
          Connect your bank accounts in Settings to see transactions here.
        </Text>
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
});
