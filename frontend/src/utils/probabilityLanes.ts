import type { Prediction } from '../types';

export interface ProbabilityLanes {
  low: number;
  moderate: number;
  severe: number;
  critical: number;
}

export const clampMetric = (value: number, min = 0, max = 100) => {
  return Math.min(max, Math.max(min, Number.isFinite(value) ? value : 0));
};

export const deriveProbabilityLanes = (prediction: Prediction | null): ProbabilityLanes => {
  const confidence = clampMetric(Number(prediction?.confidence_percent || 0));
  const probs = prediction?.probabilities || {};
  const rawLanes = {
    low: clampMetric(Number(probs.LOW || 0)),
    moderate: clampMetric(Number(probs.MODERATE || 0)),
    severe: clampMetric(Number(probs.SEVERE || 0)),
    critical: clampMetric(Number(probs.CRITICAL || probs.HIGH || 0)),
  };

  const suppliedTotal = rawLanes.low + rawLanes.moderate + rawLanes.severe + rawLanes.critical;
  if (suppliedTotal > 0) {
    const scale = suppliedTotal > 100 ? 100 / suppliedTotal : 1;
    return {
      low: clampMetric(rawLanes.low * scale),
      moderate: clampMetric(rawLanes.moderate * scale),
      severe: clampMetric(rawLanes.severe * scale),
      critical: clampMetric(rawLanes.critical * scale),
    };
  }

  const remainder = clampMetric(100 - confidence);
  switch (prediction?.severity) {
    case 'CRITICAL':
      return {
        low: clampMetric(remainder * 0.08),
        moderate: clampMetric(remainder * 0.18),
        severe: clampMetric(remainder * 0.29),
        critical: confidence,
      };
    case 'SEVERE':
      return {
        low: clampMetric(remainder * 0.12),
        moderate: clampMetric(remainder * 0.24),
        severe: confidence,
        critical: clampMetric(remainder * 0.18),
      };
    case 'MODERATE':
      return {
        low: clampMetric(remainder * 0.22),
        moderate: confidence,
        severe: clampMetric(remainder * 0.2),
        critical: clampMetric(remainder * 0.08),
      };
    default:
      return {
        low: confidence || 72,
        moderate: clampMetric(remainder * 0.24),
        severe: clampMetric(remainder * 0.12),
        critical: clampMetric(remainder * 0.06),
      };
  }
};

export const getDominantProbabilityLane = (lanes: ProbabilityLanes) => {
  return ([
    ['LOW', lanes.low],
    ['MODERATE', lanes.moderate],
    ['SEVERE', lanes.severe],
    ['CRITICAL', lanes.critical],
  ] as Array<[string, number]>).reduce<[string, number]>(
    (winner, current) => (current[1] > winner[1] ? current : winner),
    ['LOW', 0],
  );
};
