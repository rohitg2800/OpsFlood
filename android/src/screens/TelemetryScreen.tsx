/**
 * TelemetryScreen
 * - Option A: gates the entire live feed behind allowLiveCWC from /health
 * - Option B: SourcePolicyBanner rendered at the top of every state
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  FlatList,
  RefreshControl,
  StyleSheet,
  SafeAreaView,
  TouchableOpacity,
} from 'react-native';
import { useHealth } from '../hooks/useHealth';
import { useLiveTelemetry } from '../hooks/useLiveTelemetry';
import { SourcePolicyBanner } from '../components/SourcePolicyBanner';
import { PolicyLockedScreen } from '../components/PolicyLockedScreen';
import { SensorCard } from '../components/SensorCard';
import type { SensorNode } from '../types/telemetry';

const STATES = ['Maharashtra', 'Bihar', 'Kerala', 'Assam', 'Uttarakhand', 'Gujarat', 'Odisha', 'West Bengal', 'Uttar Pradesh', 'Punjab', 'Tamil Nadu'];
const DEFAULT_STATIONS: Record<string, string> = {
  Maharashtra: 'Kolhapur', Bihar: 'Patna', Kerala: 'Kochi', Assam: 'Guwahati',
  Uttarakhand: 'Dehradun', Gujarat: 'Surat', Odisha: 'Bhubaneswar',
  'West Bengal': 'Kolkata', 'Uttar Pradesh': 'Lucknow', Punjab: 'Chandigarh', 'Tamil Nadu': 'Chennai',
};

export const TelemetryScreen: React.FC = () => {
  const { allowLiveCWC, policyLabel, policyMode, telemetryMode, status: healthStatus, health, refresh: refreshHealth } = useHealth();
  const [selectedState, setSelectedState] = useState('Maharashtra');
  const station = DEFAULT_STATIONS[selectedState] ?? 'Kolhapur';

  const { data, loading, error, lastFetched, refresh: refreshTelemetry } = useLiveTelemetry({
    state: selectedState,
    station,
    limit: 6,
    enabled: allowLiveCWC,
    autoRefreshMs: 30_000,
  });

  const handleRefresh = () => {
    void refreshHealth();
    if (allowLiveCWC) void refreshTelemetry();
  };

  return (
    <SafeAreaView style={styles.safe}>
      {/* Option B — always-visible policy banner */}
      <SourcePolicyBanner
        policyLabel={policyLabel}
        policyMode={policyMode}
        telemetryMode={telemetryMode}
        allowLiveCWC={allowLiveCWC}
        healthStatus={healthStatus}
        onRefresh={handleRefresh}
      />

      {/* Option A — gate the UI on allow_live_cwc_in_app */}
      {healthStatus !== 'loading' && !allowLiveCWC ? (
        <PolicyLockedScreen
          policyLabel={policyLabel}
          policyDescription={health?.source_policy?.description}
          onRefresh={handleRefresh}
        />
      ) : (
        <FlatList<SensorNode>
          data={data}
          keyExtractor={(item) => item.station}
          renderItem={({ item }) => <SensorCard sensor={item} />}
          contentContainerStyle={styles.list}
          refreshControl={
            <RefreshControl
              refreshing={loading}
              onRefresh={handleRefresh}
              tintColor="#22c55e"
            />
          }
          ListHeaderComponent={
            <View style={styles.header}>
              {/* State selector chips */}
              <Text style={styles.headerLabel}>State</Text>
              <View style={styles.chips}>
                {STATES.map((s) => (
                  <TouchableOpacity
                    key={s}
                    onPress={() => setSelectedState(s)}
                    style={[
                      styles.chip,
                      s === selectedState && styles.chipActive,
                    ]}
                    activeOpacity={0.7}
                  >
                    <Text style={[styles.chipText, s === selectedState && styles.chipTextActive]}>
                      {s}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
              {lastFetched ? (
                <Text style={styles.lastFetched}>
                  Last synced {lastFetched.toLocaleTimeString('en-US', { hour12: false })}
                </Text>
              ) : null}
              {error ? <Text style={styles.error}>{error}</Text> : null}
            </View>
          }
          ListEmptyComponent={
            !loading ? (
              <View style={styles.empty}>
                <Text style={styles.emptyIcon}>📡</Text>
                <Text style={styles.emptyText}>No telemetry nodes for {selectedState}</Text>
                <Text style={styles.emptyHint}>Pull down to refresh or switch state.</Text>
              </View>
            ) : null
          }
        />
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: '#060a0e' },
  list: { padding: 16, paddingBottom: 32 },
  header: { marginBottom: 16 },
  headerLabel: { fontSize: 10, fontWeight: '700', color: '#4a6070', letterSpacing: 1, textTransform: 'uppercase', marginBottom: 8 },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginBottom: 12 },
  chip: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 8,
    backgroundColor: '#0d1520',
    borderWidth: 1,
    borderColor: '#1a2535',
  },
  chipActive: { backgroundColor: '#0d2318', borderColor: '#22c55e55' },
  chipText: { fontSize: 10, color: '#4a6070', fontWeight: '600' },
  chipTextActive: { color: '#86efac' },
  lastFetched: { fontSize: 9, color: '#2a3a4a', letterSpacing: 0.4, textTransform: 'uppercase' },
  error: { fontSize: 11, color: '#ff8090', marginTop: 6 },
  empty: { alignItems: 'center', paddingTop: 60, gap: 10 },
  emptyIcon: { fontSize: 40 },
  emptyText: { fontSize: 14, color: '#4a6070', fontWeight: '600', textAlign: 'center' },
  emptyHint: { fontSize: 11, color: '#2a3a4a', textAlign: 'center' },
});
