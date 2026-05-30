import type { AppState } from '../types';

type LiveSource = AppState['cwc']['liveData']['source'];
type PredictionSource = AppState['prediction']['cwcDataSource'];
type SourcePolicyMode = AppState['system']['sourcePolicy']['mode'];

interface CWCDataSourceMessageOptions {
  isConnected: boolean;
  liveSource?: LiveSource | null;
  predictionSource?: PredictionSource | null;
  sourcePolicyMode?: SourcePolicyMode | null;
}

export function getCWCDataSourceMessage({
  isConnected,
  liveSource,
  predictionSource,
  sourcePolicyMode,
}: CWCDataSourceMessageOptions): string {
  if (sourcePolicyMode === 'OPEN_DATA') {
    return 'Open data mode • use licensed public datasets and manual context inside the app';
  }

  if (sourcePolicyMode === 'OFFICIAL_VIEW_ONLY') {
    return 'Official view only • use CWC portals for live monitoring while the app stays on manual context';
  }

  if (isConnected) {
    if (liveSource === 'HTML_SCRAPE') {
      return 'HTML scrape • Live CWC station query';
    }

    return 'CWC API • Live CWC station query';
  }

  if (predictionSource === 'LOCAL_CACHE' || liveSource === 'CACHED') {
    return 'Cached mode • using recent CWC context while live feed reconnects';
  }

  return 'Fallback mode • using manual threshold context until CWC responds';
}
