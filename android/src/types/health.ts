export interface SourcePolicy {
  mode: string;
  label: string;
  description: string;
  allow_live_cwc_in_app: boolean;
  telemetry_mode: string;
  prediction_data_source: string;
  public_sources: Array<{
    label: string;
    title: string;
    url: string;
    usage: string;
  }>;
}

export interface HealthResponse {
  status: string;
  service: string;
  model_ready: boolean;
  version: string;
  source_policy: SourcePolicy;
  database: {
    backend: string;
    configured: boolean;
    ready: boolean;
    message: string;
  };
  time: string;
}
