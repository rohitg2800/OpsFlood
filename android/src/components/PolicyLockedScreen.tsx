/**
 * PolicyLockedScreen — shown inside TelemetryScreen when
 * allowLiveCWC is false (Option A: gate the UI on the policy flag).
 */
import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';

interface Props {
  policyLabel: string | null;
  policyDescription?: string;
  onRefresh: () => void;
}

export const PolicyLockedScreen: React.FC<Props> = ({ policyLabel, policyDescription, onRefresh }) => (
  <View style={styles.root}>
    <View style={styles.iconWrap}>
      <Text style={styles.icon}>🔒</Text>
    </View>
    <Text style={styles.title}>Live CWC Telemetry Locked</Text>
    <Text style={styles.policy}>{policyLabel ?? 'Policy active'}</Text>
    {policyDescription ? (
      <Text style={styles.desc}>{policyDescription}</Text>
    ) : null}
    <Text style={styles.hint}>
      The current source policy does not permit live in-app CWC detection.
      {`\n`}Tap below once the server policy changes.
    </Text>
    <TouchableOpacity style={styles.btn} onPress={onRefresh} activeOpacity={0.8}>
      <Text style={styles.btnText}>Re-check Policy</Text>
    </TouchableOpacity>
  </View>
);

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#080c10',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 32,
    gap: 16,
  },
  iconWrap: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: '#1a0a00',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#f59e0b40',
    marginBottom: 8,
  },
  icon: { fontSize: 32 },
  title: {
    fontSize: 18,
    fontWeight: '700',
    color: '#fcd34d',
    textAlign: 'center',
    letterSpacing: 0.3,
  },
  policy: {
    fontSize: 12,
    fontWeight: '700',
    color: '#f59e0b',
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  desc: {
    fontSize: 13,
    color: '#7090a0',
    textAlign: 'center',
    lineHeight: 20,
  },
  hint: {
    fontSize: 12,
    color: '#4a6070',
    textAlign: 'center',
    lineHeight: 18,
    marginTop: 8,
  },
  btn: {
    marginTop: 16,
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 10,
    backgroundColor: '#1e2a1a',
    borderWidth: 1,
    borderColor: '#22c55e40',
  },
  btnText: {
    color: '#86efac',
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 0.5,
  },
});
