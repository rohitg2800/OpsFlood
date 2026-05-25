import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import type { SensorNode } from '../types/telemetry';

const STATUS_COLORS: Record<string, string> = {
  CRITICAL: '#ff4455',
  WARNING: '#f59e0b',
  ACTIVE: '#22c55e',
};

const TREND_SYMBOL: Record<string, string> = {
  RISING: '↑',
  FALLING: '↓',
  STEADY: '→',
};

export const SensorCard: React.FC<{ sensor: SensorNode }> = ({ sensor }) => {
  const statusColor = STATUS_COLORS[sensor.status] ?? '#7090a0';
  const trend = TREND_SYMBOL[sensor.trend ?? 'STEADY'] ?? '→';

  return (
    <View style={styles.card}>
      <View style={styles.header}>
        <View style={styles.left}>
          <Text style={styles.station} numberOfLines={1}>{sensor.station}</Text>
          <Text style={styles.river} numberOfLines={1}>{sensor.river ?? 'Active basin'}</Text>
        </View>
        <View style={[styles.badge, { borderColor: statusColor + '55', backgroundColor: statusColor + '18' }]}>
          <Text style={[styles.badgeText, { color: statusColor }]}>{sensor.status}</Text>
        </View>
      </View>

      <View style={styles.metrics}>
        <View style={styles.metricBox}>
          <Text style={styles.metricLabel}>Water Level</Text>
          <Text style={styles.metricValue}>{Number(sensor.river_level ?? 0).toFixed(2)}m</Text>
        </View>
        <View style={styles.metricBox}>
          <Text style={styles.metricLabel}>Rain 1H</Text>
          <Text style={styles.metricValue}>{Number(sensor.rainfall_last_hour ?? 0).toFixed(1)}mm</Text>
        </View>
        <View style={styles.metricBox}>
          <Text style={styles.metricLabel}>Trend</Text>
          <Text style={[styles.metricValue, { color: sensor.trend === 'RISING' ? '#f59e0b' : sensor.trend === 'FALLING' ? '#22c55e' : '#7090a0' }]}>
            {trend} {sensor.trend ?? 'STEADY'}
          </Text>
        </View>
      </View>

      {sensor.last_update ? (
        <Text style={styles.ts}>
          Last sync: {new Date(sensor.last_update).toLocaleTimeString('en-US', { hour12: false })}
        </Text>
      ) : null}
    </View>
  );
};

const styles = StyleSheet.create({
  card: {
    backgroundColor: '#0d1520',
    borderRadius: 14,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#1a2535',
  },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 14 },
  left: { flex: 1, marginRight: 10 },
  station: { fontSize: 15, fontWeight: '700', color: '#e8edf2', letterSpacing: 0.3 },
  river: { fontSize: 11, color: '#4a7090', marginTop: 3, letterSpacing: 0.2 },
  badge: {
    borderRadius: 6,
    borderWidth: 1,
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  badgeText: { fontSize: 9, fontWeight: '800', letterSpacing: 1.2, textTransform: 'uppercase' },
  metrics: { flexDirection: 'row', gap: 8, marginBottom: 10 },
  metricBox: {
    flex: 1,
    backgroundColor: '#080c10',
    borderRadius: 10,
    padding: 10,
  },
  metricLabel: { fontSize: 9, color: '#4a6070', fontWeight: '600', letterSpacing: 0.8, textTransform: 'uppercase' },
  metricValue: { fontSize: 18, fontWeight: '600', color: '#c8d8e8', marginTop: 4, fontVariant: ['tabular-nums'] },
  ts: { fontSize: 9, color: '#2a3a4a', letterSpacing: 0.4, textTransform: 'uppercase', marginTop: 2 },
});
