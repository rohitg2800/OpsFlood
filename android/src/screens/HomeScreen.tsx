import React from 'react';
import { View, Text, ScrollView, StyleSheet, SafeAreaView, TouchableOpacity, Linking } from 'react-native';
import { useHealth } from '../hooks/useHealth';
import { SourcePolicyBanner } from '../components/SourcePolicyBanner';

export const HomeScreen: React.FC = () => {
  const { health, status, allowLiveCWC, policyLabel, policyMode, telemetryMode, modelReady, refresh } = useHealth();

  return (
    <SafeAreaView style={styles.safe}>
      <SourcePolicyBanner
        policyLabel={policyLabel}
        policyMode={policyMode}
        telemetryMode={telemetryMode}
        allowLiveCWC={allowLiveCWC}
        healthStatus={status}
        onRefresh={refresh}
      />
      <ScrollView contentContainerStyle={styles.container}>
        {/* Hero */}
        <View style={styles.hero}>
          <Text style={styles.heroEyebrow}>OpsFlood ML</Text>
          <Text style={styles.heroTitle}>India Flood{`\n`}Intelligence</Text>
          <Text style={styles.heroSub}>Real-time CWC telemetry · ML flood prediction · State severity matrix</Text>
        </View>

        {/* Server status card */}
        <View style={styles.card}>
          <Text style={styles.cardLabel}>Server</Text>
          <View style={styles.row}>
            <View style={[styles.statusDot, { backgroundColor: status === 'online' ? '#22c55e' : status === 'loading' ? '#f59e0b' : '#ff4455' }]} />
            <Text style={styles.cardValue}>
              {status === 'online' ? health?.service ?? 'Online' : status === 'loading' ? 'Connecting…' : 'Offline'}
            </Text>
          </View>
          {health?.version ? <Text style={styles.cardSub}>v{health.version}</Text> : null}
        </View>

        {/* Model status */}
        <View style={styles.card}>
          <Text style={styles.cardLabel}>ML Model</Text>
          <View style={styles.row}>
            <View style={[styles.statusDot, { backgroundColor: modelReady ? '#22c55e' : '#f59e0b' }]} />
            <Text style={styles.cardValue}>{modelReady ? 'Ready' : 'Not ready'}</Text>
          </View>
          {health?.database?.ready ? <Text style={styles.cardSub}>PostgreSQL · ready</Text> : null}
        </View>

        {/* Source policy detail card */}
        {health?.source_policy ? (
          <View style={styles.card}>
            <Text style={styles.cardLabel}>Source Policy</Text>
            <Text style={styles.cardValue}>{health.source_policy.label}</Text>
            <Text style={styles.cardSub}>{health.source_policy.description}</Text>
            <View style={styles.row} style={{ marginTop: 10, gap: 6, flexWrap: 'wrap' } as any}>
              {[
                { k: 'Mode', v: health.source_policy.mode },
                { k: 'Telemetry', v: health.source_policy.telemetry_mode },
                { k: 'Live CWC', v: health.source_policy.allow_live_cwc_in_app ? 'Enabled ✓' : 'Locked ✗' },
              ].map(({ k, v }) => (
                <View key={k} style={styles.pill}>
                  <Text style={styles.pillKey}>{k}</Text>
                  <Text style={styles.pillVal}>{v}</Text>
                </View>
              ))}
            </View>

            {/* Public sources */}
            {health.source_policy.public_sources?.length ? (
              <View style={{ marginTop: 12 }}>
                <Text style={styles.cardLabel}>Official Sources</Text>
                {health.source_policy.public_sources.map((src) => (
                  <TouchableOpacity key={src.url} onPress={() => Linking.openURL(src.url)} style={styles.sourceRow}>
                    <Text style={styles.sourceLabel}>{src.label}</Text>
                    <Text style={styles.sourceTitle} numberOfLines={1}>{src.title}</Text>
                  </TouchableOpacity>
                ))}
              </View>
            ) : null}
          </View>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: '#060a0e' },
  container: { padding: 20, paddingBottom: 40, gap: 16 },
  hero: { paddingVertical: 24, gap: 8 },
  heroEyebrow: { fontSize: 10, fontWeight: '800', color: '#22c55e', letterSpacing: 2, textTransform: 'uppercase' },
  heroTitle: { fontSize: 34, fontWeight: '800', color: '#e8edf2', lineHeight: 40, letterSpacing: -0.5 },
  heroSub: { fontSize: 13, color: '#4a6070', lineHeight: 20 },
  card: { backgroundColor: '#0d1520', borderRadius: 14, padding: 16, borderWidth: 1, borderColor: '#1a2535', gap: 6 },
  cardLabel: { fontSize: 9, fontWeight: '700', color: '#4a6070', letterSpacing: 1, textTransform: 'uppercase' },
  cardValue: { fontSize: 16, fontWeight: '700', color: '#c8d8e8' },
  cardSub: { fontSize: 11, color: '#4a6070' },
  row: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  statusDot: { width: 8, height: 8, borderRadius: 4 },
  pill: { backgroundColor: '#080c10', borderRadius: 8, paddingHorizontal: 10, paddingVertical: 6, borderWidth: 1, borderColor: '#1a2535' },
  pillKey: { fontSize: 8, color: '#4a6070', fontWeight: '700', letterSpacing: 0.8, textTransform: 'uppercase' },
  pillVal: { fontSize: 12, color: '#c8d8e8', fontWeight: '600', marginTop: 2 },
  sourceRow: { paddingVertical: 8, borderBottomWidth: 1, borderBottomColor: '#0d1520', gap: 2 },
  sourceLabel: { fontSize: 9, color: '#22c55e', fontWeight: '700', letterSpacing: 0.8, textTransform: 'uppercase' },
  sourceTitle: { fontSize: 12, color: '#7090a0' },
});
