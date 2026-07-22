import React, { useState, useMemo } from 'react';
import {
  View, Text, ScrollView, StyleSheet, TouchableOpacity, Modal, TextInput, KeyboardAvoidingView, Platform, Switch,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { colors, typography, spacing, borderRadius, shadows } from '../theme/pink';
import { CONTRIBUTION_LABELS, ContributionLabel, MonthlyContributionSummary } from '../models/types';
import { formatCurrency } from '../utils/formatters';
import { useData } from '../context/DataContext';

export default function ContributionsScreen() {
  const {
    contributions,
    monthlyTarget,
    addManualContribution,
    recurringContributions,
    addRecurringContribution,
    setRecurringContributionActive,
    deleteRecurringContribution,
  } = useData();
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());
  const [showAddModal, setShowAddModal] = useState(false);
  const [newAmount, setNewAmount] = useState('');
  const [newLabel, setNewLabel] = useState<ContributionLabel>('TSP');
  const [isSaving, setIsSaving] = useState(false);

  const [showRecurringModal, setShowRecurringModal] = useState(false);
  const [recurringAmount, setRecurringAmount] = useState('');
  const [recurringLabel, setRecurringLabel] = useState<ContributionLabel>('401(k)');
  const [recurringNote, setRecurringNote] = useState('');
  const [isSavingRecurring, setIsSavingRecurring] = useState(false);

  const annualSummary = useMemo(() => {
    const yearContribs = contributions.filter(c => {
      const d = new Date(c.date);
      return d.getFullYear() === selectedYear;
    });

    const months: MonthlyContributionSummary[] = Array.from({ length: 12 }, (_, i) => {
      const month = i + 1;
      const monthContribs = yearContribs.filter(c => new Date(c.date).getMonth() + 1 === month);
      const tsp = monthContribs.filter(c => c.label === 'TSP').reduce((s, c) => s + c.amount, 0);
      const k401 = monthContribs.filter(c => c.label === '401(k)').reduce((s, c) => s + c.amount, 0);
      const roth = monthContribs.filter(c => c.label === 'Roth IRA').reduce((s, c) => s + c.amount, 0);
      const other = monthContribs.filter(c => c.label === 'Other').reduce((s, c) => s + c.amount, 0);
      return { month, year: selectedYear, tsp, k401, roth, other, total: tsp + k401 + roth + other };
    });

    const totalContributed = months.reduce((s, m) => s + m.total, 0);
    const annualTarget = monthlyTarget * 12;
    const monthsWithData = months.filter(m => m.total > 0).length;

    return {
      year: selectedYear,
      months,
      monthlyTarget,
      totalContributed,
      annualTarget,
      percentOfTarget: annualTarget > 0 ? totalContributed / annualTarget : 0,
      averageMonthly: monthsWithData > 0 ? totalContributed / monthsWithData : 0,
      remainingToTarget: annualTarget - totalContributed,
      tspTotal: months.reduce((s, m) => s + m.tsp, 0),
      k401Total: months.reduce((s, m) => s + m.k401, 0),
      rothTotal: months.reduce((s, m) => s + m.roth, 0),
      otherTotal: months.reduce((s, m) => s + m.other, 0),
    };
  }, [contributions, selectedYear, monthlyTarget]);

  const MONTH_NAMES = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const FULL_MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];

  const resetAddForm = () => {
    setNewAmount('');
    setNewLabel('TSP');
  };

  const handleSave = async () => {
    const amount = parseFloat(newAmount);
    if (!amount || amount <= 0) return;

    setIsSaving(true);
    try {
      await addManualContribution({
        date: new Date().toISOString(),
        amount,
        label: newLabel,
        notes: null,
        linkedTransactionId: null,
        recurringContributionId: null,
      });
      resetAddForm();
      setShowAddModal(false);
    } finally {
      setIsSaving(false);
    }
  };

  const resetRecurringForm = () => {
    setRecurringAmount('');
    setRecurringLabel('401(k)');
    setRecurringNote('');
  };

  const handleSaveRecurring = async () => {
    const amount = parseFloat(recurringAmount);
    if (!amount || amount <= 0) return;

    setIsSavingRecurring(true);
    try {
      await addRecurringContribution({
        amount,
        label: recurringLabel,
        note: recurringNote.trim() || null,
        isActive: true,
      });
      resetRecurringForm();
      setShowRecurringModal(false);
    } finally {
      setIsSavingRecurring(false);
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Year Picker */}
      <View style={styles.yearPicker}>
        <TouchableOpacity onPress={() => setSelectedYear(y => y - 1)}>
          <Ionicons name="chevron-back" size={24} color={colors.pinkPrimary} />
        </TouchableOpacity>
        <Text style={styles.yearText}>{selectedYear}</Text>
        <TouchableOpacity onPress={() => setSelectedYear(y => y + 1)}>
          <Ionicons name="chevron-forward" size={24} color={colors.pinkPrimary} />
        </TouchableOpacity>
      </View>

      {/* YTD Card */}
      <View style={[styles.card, shadows.card]}>
        <Text style={styles.ytdLabel}>Year to Date</Text>
        <Text style={styles.bigMoney}>{formatCurrency(annualSummary.totalContributed)}</Text>
        <Text style={styles.targetText}>
          of {formatCurrency(annualSummary.annualTarget)} annual target
        </Text>

        <View style={styles.statsRow}>
          <View style={styles.miniStat}>
            <Text style={styles.miniValue}>{formatCurrency(annualSummary.remainingToTarget)}</Text>
            <Text style={styles.miniLabel}>Remaining</Text>
          </View>
          <View style={styles.miniStat}>
            <Text style={styles.miniValue}>{formatCurrency(annualSummary.averageMonthly)}</Text>
            <Text style={styles.miniLabel}>Avg/Month</Text>
          </View>
          <View style={styles.miniStat}>
            <Text style={styles.miniValue}>{Math.round(annualSummary.percentOfTarget * 100)}%</Text>
            <Text style={styles.miniLabel}>Progress</Text>
          </View>
        </View>
      </View>

      {/* Simple Bar Chart */}
      <View style={[styles.card, shadows.card]}>
        <Text style={styles.sectionTitle}>Monthly Contributions</Text>
        <View style={styles.chartContainer}>
          {annualSummary.months.map((month, i) => {
            const maxVal = Math.max(monthlyTarget, ...annualSummary.months.map(m => m.total));
            const barHeight = maxVal > 0 ? (month.total / maxVal) * 140 : 0;
            const targetHeight = maxVal > 0 ? (monthlyTarget / maxVal) * 140 : 0;

            return (
              <View key={i} style={styles.barColumn}>
                <View style={styles.barWrapper}>
                  {/* Target line */}
                  <View style={[styles.targetLine, { bottom: targetHeight }]} />
                  {/* Bar */}
                  <View style={[styles.bar, {
                    height: barHeight,
                    backgroundColor: month.total >= monthlyTarget ? colors.success : colors.pinkPrimary,
                  }]} />
                </View>
                <Text style={styles.barLabel}>{MONTH_NAMES[i]}</Text>
              </View>
            );
          })}
        </View>
      </View>

      {/* Account Breakdown */}
      <View style={[styles.card, shadows.card]}>
        <Text style={styles.sectionTitle}>By Account (YTD)</Text>
        {[
          { label: 'TSP', amount: annualSummary.tspTotal, color: colors.tsp },
          { label: '401(k)', amount: annualSummary.k401Total, color: colors.k401 },
          { label: 'Roth IRA', amount: annualSummary.rothTotal, color: colors.roth },
          { label: 'Other', amount: annualSummary.otherTotal, color: colors.other },
        ].map(({ label, amount, color }) => (
          <View key={label} style={styles.accountRow}>
            <View style={[styles.dot, { backgroundColor: color }]} />
            <Text style={styles.accountLabel}>{label}</Text>
            <Text style={styles.accountAmount}>{formatCurrency(amount)}</Text>
          </View>
        ))}
        <View style={styles.totalRow}>
          <Text style={styles.totalLabel}>Total</Text>
          <Text style={styles.totalAmount}>{formatCurrency(annualSummary.totalContributed)}</Text>
        </View>
      </View>

      {/* Recurring Contributions */}
      <View style={[styles.card, shadows.card]}>
        <Text style={styles.sectionTitle}>Recurring Contributions</Text>
        <Text style={styles.recurringHint}>
          For amounts Plaid can't see, like an employer 401(k). Added automatically once a
          month, the first time you open the app that month.
        </Text>

        {recurringContributions.length === 0 ? (
          <Text style={styles.recurringEmpty}>No recurring contributions set up yet.</Text>
        ) : (
          recurringContributions.map(item => (
            <View key={item.id} style={styles.recurringRow}>
              <View style={{ flex: 1 }}>
                <Text style={styles.recurringLabel}>
                  {item.label}
                  {item.note ? ` — ${item.note}` : ''}
                </Text>
                <Text style={styles.recurringAmount}>{formatCurrency(item.amount)}/mo</Text>
              </View>
              <Switch
                value={item.isActive}
                onValueChange={value => setRecurringContributionActive(item.id, value)}
                trackColor={{ true: colors.pinkPrimary }}
              />
              <TouchableOpacity
                onPress={() => deleteRecurringContribution(item.id)}
                style={styles.recurringDelete}
              >
                <Ionicons name="trash-outline" size={18} color={colors.danger} />
              </TouchableOpacity>
            </View>
          ))
        )}

        <TouchableOpacity style={styles.addRecurringButton} onPress={() => setShowRecurringModal(true)}>
          <Ionicons name="add" size={18} color={colors.pinkPrimary} />
          <Text style={styles.addRecurringButtonText}>Add Recurring Contribution</Text>
        </TouchableOpacity>
      </View>

      {/* Monthly Detail */}
      <View style={[styles.card, shadows.card]}>
        <Text style={styles.sectionTitle}>Month by Month</Text>
        {[...annualSummary.months].reverse().map((month) => {
          const diff = month.total - monthlyTarget;
          return (
            <View key={month.month} style={styles.monthRow}>
              <Text style={styles.monthName}>{FULL_MONTHS[month.month - 1]}</Text>
              <View style={{ alignItems: 'flex-end' }}>
                <Text style={[styles.monthTotal, month.total >= monthlyTarget && { color: colors.success }]}>
                  {formatCurrency(month.total)}
                </Text>
                {month.total > 0 && (
                  <Text style={[styles.monthDiff, { color: diff >= 0 ? colors.success : colors.danger }]}>
                    {diff >= 0 ? '+' : ''}{formatCurrency(diff)}
                  </Text>
                )}
              </View>
            </View>
          );
        })}
      </View>

      {/* Add Button */}
      <TouchableOpacity style={styles.addButton} onPress={() => setShowAddModal(true)}>
        <Ionicons name="add-circle" size={20} color="#fff" />
        <Text style={styles.addButtonText}>Add Contribution</Text>
      </TouchableOpacity>

      <View style={{ height: 40 }} />

      {/* Add Contribution Modal */}
      <Modal
        visible={showAddModal}
        animationType="slide"
        transparent
        onRequestClose={() => setShowAddModal(false)}
      >
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
          style={styles.modalOverlay}
        >
          <View style={styles.modalCard}>
            <Text style={styles.modalTitle}>Add Contribution</Text>

            <Text style={styles.modalLabel}>Amount</Text>
            <TextInput
              style={styles.modalInput}
              value={newAmount}
              onChangeText={setNewAmount}
              keyboardType="decimal-pad"
              placeholder="$0"
              autoFocus
            />

            <Text style={styles.modalLabel}>Account</Text>
            <View style={styles.labelRow}>
              {CONTRIBUTION_LABELS.map(label => (
                <TouchableOpacity
                  key={label}
                  style={[styles.labelChip, newLabel === label && styles.labelChipActive]}
                  onPress={() => setNewLabel(label)}
                >
                  <Text style={[styles.labelChipText, newLabel === label && styles.labelChipTextActive]}>
                    {label}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            <View style={styles.modalButtonRow}>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalCancelButton]}
                onPress={() => {
                  resetAddForm();
                  setShowAddModal(false);
                }}
              >
                <Text style={styles.modalCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalSaveButton, isSaving && { opacity: 0.6 }]}
                onPress={handleSave}
                disabled={isSaving || !newAmount}
              >
                <Text style={styles.modalSaveText}>{isSaving ? 'Saving…' : 'Save'}</Text>
              </TouchableOpacity>
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>

      {/* Add Recurring Contribution Modal */}
      <Modal
        visible={showRecurringModal}
        animationType="slide"
        transparent
        onRequestClose={() => setShowRecurringModal(false)}
      >
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
          style={styles.modalOverlay}
        >
          <View style={styles.modalCard}>
            <Text style={styles.modalTitle}>Add Recurring Contribution</Text>

            <Text style={styles.modalLabel}>Monthly Amount</Text>
            <TextInput
              style={styles.modalInput}
              value={recurringAmount}
              onChangeText={setRecurringAmount}
              keyboardType="decimal-pad"
              placeholder="$0"
              autoFocus
            />

            <Text style={styles.modalLabel}>Account</Text>
            <View style={styles.labelRow}>
              {CONTRIBUTION_LABELS.map(label => (
                <TouchableOpacity
                  key={label}
                  style={[styles.labelChip, recurringLabel === label && styles.labelChipActive]}
                  onPress={() => setRecurringLabel(label)}
                >
                  <Text style={[styles.labelChipText, recurringLabel === label && styles.labelChipTextActive]}>
                    {label}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            <Text style={styles.modalLabel}>Note (optional)</Text>
            <TextInput
              style={styles.noteInput}
              value={recurringNote}
              onChangeText={setRecurringNote}
              placeholder="e.g. Tire Rack employer 401(k)"
            />

            <View style={styles.modalButtonRow}>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalCancelButton]}
                onPress={() => {
                  resetRecurringForm();
                  setShowRecurringModal(false);
                }}
              >
                <Text style={styles.modalCancelText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={[styles.modalButton, styles.modalSaveButton, isSavingRecurring && { opacity: 0.6 }]}
                onPress={handleSaveRecurring}
                disabled={isSavingRecurring || !recurringAmount}
              >
                <Text style={styles.modalSaveText}>{isSavingRecurring ? 'Saving…' : 'Save'}</Text>
              </TouchableOpacity>
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bgPrimary },
  content: { padding: spacing.lg },
  yearPicker: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.lg },
  yearText: { ...typography.title, color: colors.textPrimary },
  card: { backgroundColor: colors.bgCard, borderRadius: borderRadius.lg, padding: spacing.lg, marginBottom: spacing.lg },
  ytdLabel: { ...typography.callout, color: colors.textSecondary, textAlign: 'center' },
  bigMoney: { ...typography.money, color: colors.pinkPrimary, textAlign: 'center', marginTop: spacing.xs },
  targetText: { ...typography.caption, color: colors.textMuted, textAlign: 'center', marginTop: spacing.xs },
  statsRow: { flexDirection: 'row', marginTop: spacing.lg },
  miniStat: { flex: 1, alignItems: 'center' },
  miniValue: { ...typography.callout, color: colors.textPrimary },
  miniLabel: { ...typography.caption, color: colors.textMuted, marginTop: 2 },
  sectionTitle: { ...typography.headline, color: colors.textPrimary, marginBottom: spacing.md },
  chartContainer: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end', height: 170 },
  barColumn: { alignItems: 'center', flex: 1 },
  barWrapper: { width: 16, height: 140, justifyContent: 'flex-end', position: 'relative' },
  bar: { width: 16, borderRadius: 4 },
  targetLine: { position: 'absolute', left: -4, right: -4, height: 1.5, backgroundColor: colors.textMuted, zIndex: 1 },
  barLabel: { ...typography.caption, color: colors.textMuted, marginTop: 4, fontSize: 9 },
  accountRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.sm },
  dot: { width: 10, height: 10, borderRadius: 5, marginRight: spacing.sm },
  accountLabel: { ...typography.body, flex: 1 },
  accountAmount: { ...typography.moneySmall, color: colors.textPrimary },
  totalRow: { flexDirection: 'row', borderTopWidth: 1, borderTopColor: colors.border, paddingTop: spacing.md, marginTop: spacing.sm },
  totalLabel: { ...typography.headline, flex: 1 },
  totalAmount: { ...typography.headline },
  monthRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.sm, borderBottomWidth: 0.5, borderBottomColor: colors.border },
  monthName: { ...typography.body, width: 100 },
  monthTotal: { ...typography.callout, color: colors.textPrimary },
  monthDiff: { ...typography.caption, marginTop: 2 },
  addButton: { backgroundColor: colors.pinkPrimary, borderRadius: borderRadius.md, padding: spacing.md, flexDirection: 'row', justifyContent: 'center', alignItems: 'center', gap: spacing.sm },
  addButtonText: { ...typography.headline, color: '#fff' },
  recurringHint: { ...typography.caption, color: colors.textMuted, marginTop: -spacing.sm, marginBottom: spacing.md },
  recurringEmpty: { ...typography.body, color: colors.textMuted, paddingVertical: spacing.sm },
  recurringRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.sm, borderTopWidth: 0.5, borderTopColor: colors.border, gap: spacing.sm },
  recurringLabel: { ...typography.body, color: colors.textPrimary },
  recurringAmount: { ...typography.caption, color: colors.textMuted, marginTop: 2 },
  recurringDelete: { padding: 4 },
  addRecurringButton: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, marginTop: spacing.md, paddingVertical: spacing.sm },
  addRecurringButtonText: { ...typography.callout, color: colors.pinkPrimary },
  noteInput: {
    ...typography.body,
    color: colors.textPrimary,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: borderRadius.md,
    padding: spacing.md,
    marginBottom: spacing.lg,
  },
  modalOverlay: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(0,0,0,0.4)' },
  modalCard: { backgroundColor: colors.bgCard, borderTopLeftRadius: borderRadius.lg, borderTopRightRadius: borderRadius.lg, padding: spacing.xl },
  modalTitle: { ...typography.title2, color: colors.textPrimary, marginBottom: spacing.lg },
  modalLabel: { ...typography.callout, color: colors.textSecondary, marginBottom: spacing.sm },
  modalInput: {
    ...typography.title,
    color: colors.pinkPrimary,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: borderRadius.md,
    padding: spacing.md,
    marginBottom: spacing.lg,
  },
  labelRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginBottom: spacing.xl },
  labelChip: { backgroundColor: colors.pinkLight, borderRadius: 16, paddingHorizontal: 14, paddingVertical: 8 },
  labelChipActive: { backgroundColor: colors.pinkPrimary },
  labelChipText: { ...typography.callout, color: colors.pinkPrimary },
  labelChipTextActive: { color: '#fff' },
  modalButtonRow: { flexDirection: 'row', gap: spacing.md },
  modalButton: { flex: 1, borderRadius: borderRadius.md, padding: spacing.md, alignItems: 'center' },
  modalCancelButton: { backgroundColor: colors.pinkLight },
  modalCancelText: { ...typography.headline, color: colors.pinkPrimary },
  modalSaveButton: { backgroundColor: colors.pinkPrimary },
  modalSaveText: { ...typography.headline, color: '#fff' },
});
