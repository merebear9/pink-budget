// SettingsScreen.tsx
import React, { useState } from 'react';
import { View, Text, ScrollView, StyleSheet, TextInput, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { colors, typography, spacing, borderRadius } from '../theme/pink';
import { formatCurrency } from '../utils/formatters';

export default function SettingsScreen() {
  const [monthlyTarget, setMonthlyTarget] = useState('3500');
  const [plaidEnv, setPlaidEnv] = useState<'sandbox' | 'development' | 'production'>('sandbox');

  const target = parseFloat(monthlyTarget) || 0;

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Contribution Target */}
      <Text style={styles.sectionHeader}>RETIREMENT CONTRIBUTIONS</Text>
      <View style={styles.card}>
        <View style={styles.row}>
          <Text style={styles.label}>Monthly Target</Text>
          <TextInput
            style={styles.input}
            value={monthlyTarget}
            onChangeText={setMonthlyTarget}
            keyboardType="decimal-pad"
            placeholder="3500"
          />
        </View>
        <View style={styles.row}>
          <Text style={styles.labelMuted}>Annual Target</Text>
          <Text style={styles.valueMuted}>{formatCurrency(target * 12)}</Text>
        </View>
      </View>
      <Text style={styles.footer}>
        How much you want to contribute to retirement accounts each month across TSP, 401(k), Roth IRA, and others.
      </Text>

      {/* Accounts */}
      <Text style={styles.sectionHeader}>ACCOUNTS</Text>
      <View style={styles.card}>
        <TouchableOpacity style={styles.row}>
          <Ionicons name="business-outline" size={20} color={colors.pinkPrimary} />
          <Text style={[styles.label, { marginLeft: 8 }]}>Manage Accounts</Text>
          <Ionicons name="chevron-forward" size={20} color={colors.textMuted} />
        </TouchableOpacity>
        <TouchableOpacity style={styles.row}>
          <Ionicons name="sync-outline" size={20} color={colors.pinkPrimary} />
          <Text style={[styles.label, { marginLeft: 8 }]}>Sync Now</Text>
        </TouchableOpacity>
      </View>

      {/* Plaid */}
      <Text style={styles.sectionHeader}>PLAID</Text>
      <View style={styles.card}>
        {(['sandbox', 'development', 'production'] as const).map(env => (
          <TouchableOpacity
            key={env}
            style={styles.row}
            onPress={() => setPlaidEnv(env)}
          >
            <Text style={styles.label}>
              {env === 'sandbox' ? 'Sandbox (test)' : env === 'development' ? 'Development (real, free)' : 'Production (real, paid)'}
            </Text>
            {plaidEnv === env && (
              <Ionicons name="checkmark" size={20} color={colors.pinkPrimary} />
            )}
          </TouchableOpacity>
        ))}
      </View>
      <Text style={styles.footer}>
        Start in Sandbox to test, then switch to Development to connect real accounts (200 free API calls).
      </Text>

      {/* About */}
      <Text style={styles.sectionHeader}>ABOUT</Text>
      <View style={styles.card}>
        <View style={styles.row}>
          <Text style={styles.label}>Version</Text>
          <Text style={styles.valueMuted}>1.0.0</Text>
        </View>
        <View style={styles.row}>
          <Text style={styles.label}>Platform</Text>
          <Text style={styles.valueMuted}>React Native / Expo</Text>
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.bgPrimary },
  content: { padding: spacing.lg },
  sectionHeader: { ...typography.caption, color: colors.textMuted, marginTop: spacing.xl, marginBottom: spacing.sm, marginLeft: spacing.sm },
  card: { backgroundColor: colors.bgCard, borderRadius: borderRadius.md, overflow: 'hidden' },
  row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: spacing.lg, borderBottomWidth: 0.5, borderBottomColor: colors.border },
  label: { ...typography.body, color: colors.textPrimary, flex: 1 },
  labelMuted: { ...typography.body, color: colors.textSecondary },
  valueMuted: { ...typography.body, color: colors.textMuted },
  input: { ...typography.moneySmall, color: colors.pinkPrimary, textAlign: 'right', width: 100 },
  footer: { ...typography.caption, color: colors.textMuted, marginTop: spacing.sm, marginHorizontal: spacing.sm, marginBottom: spacing.sm },
});
