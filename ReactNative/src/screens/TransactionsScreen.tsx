// TransactionsScreen.tsx
import React, { useMemo, useState } from 'react';
import { View, Text, ScrollView, StyleSheet, TouchableOpacity, FlatList, Modal } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { colors, typography, spacing, borderRadius, shadows } from '../theme/pink';
import { Transaction, TransactionClassification, CLASSIFICATION_META } from '../models/types';
import { formatCurrency } from '../utils/formatters';
import { useData } from '../context/DataContext';

const FILTER_OPTIONS: (TransactionClassification | 'all')[] = [
  'all', 'spending', 'contribution', 'transfer', 'income',
];

// Non-spending classifications a transaction can be manually reassigned to,
// each with the fixed category label the app uses for that classification
// (mirrors mapToCategory in transactionService.ts).
const OTHER_CLASSIFICATIONS: { classification: TransactionClassification; categoryName: string }[] = [
  { classification: 'transfer', categoryName: 'Transfer' },
  { classification: 'contribution', categoryName: 'Investment' },
  { classification: 'income', categoryName: 'Income' },
  { classification: 'excluded', categoryName: 'Other' },
];

export default function TransactionsScreen() {
  const { transactions, categories, reclassifyTransaction } = useData();
  const [filter, setFilter] = useState<TransactionClassification | 'all'>('all');
  const [editingTransaction, setEditingTransaction] = useState<Transaction | null>(null);

  const filteredTransactions = useMemo(
    () => (filter === 'all' ? transactions : transactions.filter(tx => tx.classification === filter)),
    [transactions, filter]
  );

  const handleReclassify = async (classification: TransactionClassification, categoryName: string) => {
    if (!editingTransaction) return;
    await reclassifyTransaction(editingTransaction.id, classification, categoryName);
    setEditingTransaction(null);
  };

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

      {filteredTransactions.length === 0 ? (
        <View style={styles.empty}>
          <Ionicons name="list-outline" size={48} color={colors.pinkSoft} />
          <Text style={styles.emptyTitle}>No transactions yet</Text>
          <Text style={styles.emptyBody}>
            Connect your bank accounts in Settings to start importing transactions automatically.
          </Text>
        </View>
      ) : (
        <FlatList
          data={filteredTransactions}
          keyExtractor={item => item.id}
          renderItem={({ item }) => (
            <TouchableOpacity
              style={styles.txRow}
              onLongPress={() => setEditingTransaction(item)}
              delayLongPress={350}
            >
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
            </TouchableOpacity>
          )}
        />
      )}

      {/* Reclassify Modal */}
      <Modal
        visible={editingTransaction !== null}
        animationType="slide"
        transparent
        onRequestClose={() => setEditingTransaction(null)}
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalCard, shadows.card]}>
            <Text style={styles.modalTitle}>Reclassify</Text>
            <Text style={styles.modalSubtitle} numberOfLines={1}>
              {editingTransaction?.merchantName ?? editingTransaction?.name}
            </Text>

            <Text style={styles.modalLabel}>Budget category (spending)</Text>
            <View style={styles.chipWrap}>
              {categories.map(cat => (
                <TouchableOpacity
                  key={cat.id}
                  style={styles.categoryChip}
                  onPress={() => handleReclassify('spending', cat.name)}
                >
                  <Text style={styles.categoryChipText}>{cat.name}</Text>
                </TouchableOpacity>
              ))}
            </View>

            <Text style={styles.modalLabel}>Not spending</Text>
            <View style={styles.chipWrap}>
              {OTHER_CLASSIFICATIONS.map(({ classification, categoryName }) => (
                <TouchableOpacity
                  key={classification}
                  style={styles.categoryChip}
                  onPress={() => handleReclassify(classification, categoryName)}
                >
                  <Text style={styles.categoryChipText}>
                    {CLASSIFICATION_META[classification].displayName}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            <TouchableOpacity style={styles.modalCancel} onPress={() => setEditingTransaction(null)}>
              <Text style={styles.modalCancelText}>Cancel</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
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
  modalOverlay: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(0,0,0,0.4)' },
  modalCard: {
    backgroundColor: colors.bgCard,
    borderTopLeftRadius: borderRadius.lg,
    borderTopRightRadius: borderRadius.lg,
    padding: spacing.xl,
  },
  modalTitle: { ...typography.title2, color: colors.textPrimary },
  modalSubtitle: { ...typography.body, color: colors.textSecondary, marginTop: 2, marginBottom: spacing.lg },
  modalLabel: { ...typography.callout, color: colors.textSecondary, marginBottom: spacing.sm },
  chipWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginBottom: spacing.lg },
  categoryChip: { backgroundColor: colors.pinkLight, borderRadius: 16, paddingHorizontal: 14, paddingVertical: 8 },
  categoryChipText: { ...typography.callout, color: colors.pinkPrimary },
  modalCancel: { alignItems: 'center', paddingVertical: spacing.sm },
  modalCancelText: { ...typography.headline, color: colors.textMuted },
});
