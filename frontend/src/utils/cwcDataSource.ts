import type { AppState } from '../types';

type LiveSource = AppState['cwc']['liveData']['source'];
type PredictionSource = AppState['prediction']['cwcDataSource'];

interface CWCDataSourceMessageOptions {
  isConnected: boolean;
  liveSource?: LiveSource | null;
  predictionSource?: PredictionSource | null;
}

export function getCWCDataSourceMessage({
  isConnected,
  liveSource,
  predictionSource,
}: CWCDataSourceMessageOptions): string {
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
