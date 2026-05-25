/**
 * SourcePolicyBanner — Option B
 * Always-visible strip that shows the current source policy label,
 * telemetry mode, and live-CWC gate status.
 * Colour-codes: green = live CWC active, amber = policy locked.
 */
import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import type { HealthStatus } from '../hooks/useHealth';

interface Props {
  policyLabel: string | null;
  policyMode: string | null;
  telemetryMode: string | null;
  allowLiveCWC: boolean;
  healthStatus: HealthStatus;
  onRefresh?: () => void;
}

export const SourcePolicyBanner: React.FC<Props> = ({
  policyLabel,
  policyMode,
  telemetryMode,
  allowLiveCWC,
  healthStatus,
  onRefresh,
}) => {
  const isLive = allowLiveCWC && healthStatus === 'online';
  const isLoading = healthStatus === 'loading';
  const isOffline = healthStatus === 'offline' || healthStatus === 'error';

  const bannerColor = isLoading
    ? '#1e2a3a'
    : isOffline
    ? '#2a1a1a'
    : isLive
    ? '#0d2318'
    : '#2a200a';

  const dotColor = isLoading ? '#4a6080' : isOffline ? '#ff4455' : isLive ? '#22c55e' : '#f59e0b';
  const labelColor = isLoading ? '#7090a0' : isOffline ? '#ff8090' : isLive ? '#86efac' : '#fcd34d';

  const displayLabel = isLoading
    ? 'Connecting to server…'
    : isOffline
    ? 'Server unreachable — offline mode'
    : policyLabel ?? 'Unknown policy';

  const displaySub = isLoading
    ? null
    : isOffline
    ? null
    : [
        policyMode,
        telemetryMode,
        allowLiveCWC ? 'CWC Live ✓' : 'CWC Locked',
      ]
        .filter(Boolean)
        .join('  ·  ');

  return (
    <TouchableOpacity
      style={[styles.banner, { backgroundColor: bannerColor }]}
      onPress={onRefresh}
      activeOpacity={0.8}
      accessibilityLabel="Source policy status. Tap to refresh."
    >
      <View style={[styles.dot, { backgroundColor: dotColor }]} />
      <View style={styles.textWrap}>
        <Text style={[styles.label, { color: labelColor }]} numberOfLines={1}>
          {displayLabel}
        </Text>
        {displaySub ? (
          <Text style={styles.sub} numberOfLines={1}>
            {displaySub}
          </Text>
        ) : null}
      </View>
      <Text style={styles.tap}>↺</Text>
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  banner: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 8,
    gap: 10,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  textWrap: {
    flex: 1,
    gap: 2,
  },
  label: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 0.4,
  },
  sub: {
    fontSize: 10,
    color: '#4a6070',
    letterSpacing: 0.2,
  },
  tap: {
    fontSize: 14,
    color: '#4a6070',
  },
});
