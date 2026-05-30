export interface SensorNode {
  station: string;
  river?: string;
  state?: string;
  river_level: number;
  rainfall_last_hour: number;
  status: 'ACTIVE' | 'WARNING' | 'CRITICAL';
  trend?: 'RISING' | 'FALLING' | 'STEADY';
  danger_level?: number;
  warning_level?: number;
  last_update?: string;
}

export interface LiveTelemetryResponse {
  status: string;
  data_source: string;
  source_policy?: {
    mode: string;
    label: string;
    allow_live_cwc_in_app: boolean;
  };
  data: SensorNode[];
  timestamp?: string;
  snapshot_id?: string;
}
