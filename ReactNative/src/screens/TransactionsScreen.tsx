// TransactionsScreen.tsx
import React, { useState } from 'react';
import { View, Text, ScrollView, StyleSheet, TouchableOpacity, FlatList } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { colors, typography, spacing, borderRadius, shadows } from '../theme/pink';
import { TransactionClassification, CLASSIFICATION_META, Transaction } from '../models/types';
import { formatCurrency } from '../utils/formatters';

const FILTER_OPTIONS: (TransactionClassification | 'all')[] = [
  'all', 'spending', 'contribution', 'transfer', 'income',
];

export default function TransactionsScreen() {
  const [filter, setFilter] = useState<TransactionClassification | 'all'>('all');
  const [transactions] = useState<Transaction[]>([]);

  return (
    <View style={styles.container}>
      {/* Filter chips */}
      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.filterBar}>
        {FILTER_OPTIONS.map(opt => (
          <TouchableOpacity
            key={opt}
            style={[styles.chip, filter === opt && styles.chipActive]}
            onPress={() => setFilter(opt)}
          >
            <Text style={[styles.chipText, filter === opt && styles.chipTextActive]}>
              {opt === 'all' ? 'All' : opt === 'contribution' ? 'Investing' : opt.charAt(0).toUpperCase() + opt.slice(1)}
            </Text>
          </TouchableOpacity>
        ))}
      </ScrollView>

      {transactions.length === 0 ? (
        <View style={styles.empty}>
          <Ionicons name="list-outline" size={48} color={colors.pinkSoft} />
          <Text style={styles.emptyTitle}>No transactions yet</Text>
          <Text style={styles.emptyBody}>
            Connect your bank accounts in Settings to start importing transactions automatically.
          </Text>
        </View>
      ) : (
        <FlatList
          data={transactions}
          keyExtractor={item => item.id}
          renderItem={({ item }) => (
            <View style={styles.txRow}>
              <View style={[styles.txIcon, { backgroundColor: colors.pinkLight }]}>
                <Ionicons
                  name={CLASSIFICATION_META[item.classification].icon as any}
                  size={16}
                  color={colors.pinkPrimary}
                />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.txName}>{item.merchantName ?? item.name}</Text>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
                  <Text style={styles.txCategory}>{item.categoryName}</Text>
                  {item.classification !== 'spending' && (
                    <View style={styles.badge}>
                      <Text style={styles.badgeText}>
                        {item.classification === 'contribution' ? 'Investing' : CLASSIFICATION_META[item.classification].displayName}
                      </Text>
                    </View>
                  )}
                </View>
              </View>
              <Text style={[styles.txAmount, item.classification === 'income' && { color: colors.success }]}>
                {item.amount < 0 ? '+' : '-'}{formatCurrency(Math.abs(item.amount))}
              </Text>
            </View>
          )}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bgPrimary },
  filterBar: { paddingHorizontal: spacing.lg, paddingVertical: spacing.sm, maxHeight: 50 },
  chip: { backgroundColor: colors.pinkLight, borderRadius: 16, paddingHorizontal: 14, paddingVertical: 6, marginRight: 8 },
  chipActive: { backgroundColor: colors.pinkPrimary },
  chipText: { ...typography.callout, color: colors.pinkPrimary },
  chipTextActive: { color: '#fff' },
  empty: { flex: 1, justifyContent: 'center', alignItems: 'center', paddingHorizontal: 32 },
  emptyTitle: { ...typography.title2, color: colors.textPrimary, marginTop: spacing.lg },
  emptyBody: { ...typography.body, color: colors.textSecondary, textAlign: 'center', marginTop: spacing.sm },
  txRow: { flexDirection: 'row', alignItems: 'center', padding: spacing.lg, borderBottomWidth: 0.5, borderBottomColor: colors.border, backgroundColor: colors.bgCard },
  txIcon: { width: 36, height: 36, borderRadius: 18, justifyContent: 'center', alignItems: 'center', marginRight: spacing.md },
  txName: { ...typography.body, color: colors.textPrimary },
  txCategory: { ...typography.caption, color: colors.textMuted },
  badge: { backgroundColor: colors.info + '20', borderRadius: 4, paddingHorizontal: 6, paddingVertical: 1 },
  badgeText: { fontSize: 10, fontWeight: '500', color: colors.info },
  txAmount: { ...typography.callout, color: colors.textPrimary },
});
