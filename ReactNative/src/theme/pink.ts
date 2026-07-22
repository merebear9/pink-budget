// PinkBudget Theme - React Native
// Matches the iOS SwiftUI version

export const colors = {
  // Primary pinks
  pinkPrimary: '#E91E8C',
  pinkLight: '#FCE4F2',
  pinkSoft: '#F8B4D9',
  pinkDeep: '#BE185D',

  // Neutrals
  bgPrimary: '#FFF5F9',
  bgCard: '#FFFFFF',
  textPrimary: '#1F1F1F',
  textSecondary: '#6B7280',
  textMuted: '#9CA3AF',
  border: '#F3E8F0',

  // Semantic
  success: '#10B981',
  warning: '#F59E0B',
  danger: '#EF4444',
  info: '#6366F1',

  // Account colors (charts)
  tsp: '#E91E8C',
  k401: '#8B5CF6',
  roth: '#06B6D4',
  other: '#F59E0B',

  // Category colors
  catRent: '#E91E8C',
  catGroceries: '#10B981',
  catGas: '#6366F1',
  catDining: '#F59E0B',
  catSubscriptions: '#8B5CF6',
  catCats: '#EC4899',
  catPersonal: '#06B6D4',
  catMisc: '#9CA3AF',
};

export const typography = {
  largeTitle: { fontSize: 28, fontWeight: '700' as const },
  title: { fontSize: 22, fontWeight: '700' as const },
  title2: { fontSize: 20, fontWeight: '600' as const },
  headline: { fontSize: 17, fontWeight: '600' as const },
  body: { fontSize: 16, fontWeight: '400' as const },
  callout: { fontSize: 14, fontWeight: '500' as const },
  caption: { fontSize: 12, fontWeight: '400' as const },
  money: { fontSize: 32, fontWeight: '700' as const, fontFamily: 'monospace' },
  moneySmall: { fontSize: 18, fontWeight: '600' as const, fontFamily: 'monospace' },
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
};

export const borderRadius = {
  sm: 8,
  md: 12,
  lg: 16,
  full: 999,
};

export const shadows = {
  card: {
    shadowColor: '#E91E8C',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 8,
    elevation: 3,
  },
};
