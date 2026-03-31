import React, { useId, useMemo } from 'react';

export interface ProbabilityLaneSignal {
  key: string;
  label: string;
  value: number;
  fill: string;
  tone?: string;
}

interface ProbabilityHeartbeatSparklineProps {
  lane: ProbabilityLaneSignal;
  highlighted?: boolean;
  className?: string;
}

interface ProbabilityHeartbeatGraphProps {
  lanes: ProbabilityLaneSignal[];
  dominantLane: string;
  className?: string;
}

const HEARTBEAT_PATTERN = [
  0, 0.01, -0.004, 0.006, 0, 0.006, -0.008, 0.008,
  0.012, -0.02, 0.06, -0.22, 0.72, -0.3, 0.16, 0.035,
  0.01, 0.004, 0, -0.003, 0.004, 0, 0, 0,
];

const getPatternValue = (index: number, offset: number) => {
  const length = HEARTBEAT_PATTERN.length;
  return HEARTBEAT_PATTERN[(index + offset + length) % length];
};

const buildTrace = (
  width: number,
  baseline: number,
  amplitude: number,
  offset: number,
  startX = 0,
) => {
  const points = HEARTBEAT_PATTERN.map((_, index) => {
    const x = startX + (index / (HEARTBEAT_PATTERN.length - 1)) * width;
    const wave = getPatternValue(index, offset);
    const y = baseline - wave * amplitude;
    return { x, y };
  });

  const d = points
    .map((point, index) => `${index === 0 ? 'M' : 'L'} ${point.x.toFixed(2)} ${point.y.toFixed(2)}`)
    .join(' ');

  return {
    d,
    end: points[points.length - 1],
  };
};

export const ProbabilityHeartbeatSparkline: React.FC<ProbabilityHeartbeatSparklineProps> = ({
  lane,
  highlighted = false,
  className = '',
}) => {
  const sparkId = useId().replace(/:/g, '');
  const width = 124;
  const height = 26;
  const baseline = height / 2;
  const amplitude = 1.2 + (lane.value / 100) * 4.2;
  const offset = lane.key.length;
  const { d, end } = useMemo(
    () => buildTrace(width - 4, baseline, amplitude, offset, 2),
    [amplitude, baseline, offset],
  );

  return (
    <svg viewBox={`0 0 ${width} ${height}`} className={className} aria-hidden="true">
      <defs>
        <filter id={`spark-glow-${sparkId}`} x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="1.1" result="blurred" />
          <feMerge>
            <feMergeNode in="blurred" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>
      <line
        x1="2"
        y1={baseline}
        x2={width - 2}
        y2={baseline}
        stroke="rgba(255,255,255,0.08)"
        strokeWidth="1"
        strokeDasharray="3 4"
      />
      <path
        d={d}
        fill="none"
        stroke={lane.fill}
        strokeOpacity={highlighted ? 1 : 0.82}
        strokeWidth={highlighted ? 1.15 : 0.88}
        strokeLinecap="round"
        strokeLinejoin="round"
        filter={highlighted ? `url(#spark-glow-${sparkId})` : undefined}
      />
      <path
        d={d}
        fill="none"
        stroke="#fff7fb"
        strokeOpacity={highlighted ? 0.95 : 0.65}
        strokeWidth={highlighted ? 0.74 : 0.56}
        strokeLinecap="round"
        strokeLinejoin="round"
        pathLength={100}
        strokeDasharray="16 84"
        filter={highlighted ? `url(#spark-glow-${sparkId})` : undefined}
      >
        {highlighted ? (
          <animate
            attributeName="stroke-dashoffset"
            from="100"
            to="0"
            dur="1.6s"
            repeatCount="indefinite"
          />
        ) : null}
      </path>
      <circle
        cx={end.x}
        cy={end.y}
        r={highlighted ? 1.7 : 1.3}
        fill={lane.fill}
        fillOpacity={0.95}
      >
        {highlighted ? (
          <animate
            attributeName="r"
            values="1.7;2.15;1.7"
            dur="1.4s"
            repeatCount="indefinite"
          />
        ) : null}
      </circle>
    </svg>
  );
};

export const ProbabilityHeartbeatGraph: React.FC<ProbabilityHeartbeatGraphProps> = ({
  lanes,
  dominantLane,
  className = '',
}) => {
  const graphId = useId().replace(/:/g, '');
  const width = 620;
  const height = 176;
  const chartLeft = 84;
  const chartRight = width - 34;
  const chartWidth = chartRight - chartLeft;
  const topPadding = 18;
  const bottomPadding = 16;
  const usableHeight = height - topPadding - bottomPadding;
  const rowHeight = usableHeight / Math.max(lanes.length, 1);

  const traces = useMemo(() => {
    return lanes.map((lane, index) => {
      const baseline = topPadding + rowHeight * index + rowHeight / 2;
      const amplitude = Math.min(rowHeight * 0.26, 1.4 + (lane.value / 100) * rowHeight * 0.16);
      const offset = index * 2 + lane.key.length;
      return {
        lane,
        baseline,
        ...buildTrace(chartWidth, baseline, amplitude, offset, chartLeft),
      };
    });
  }, [chartWidth, lanes, rowHeight]);

  return (
    <div className={className}>
      <svg viewBox={`0 0 ${width} ${height}`} className="h-full w-full" aria-hidden="true">
        <defs>
          {lanes.map((lane) => (
            <filter key={lane.key} id={`heartbeat-glow-${graphId}-${lane.key}`} x="-50%" y="-50%" width="200%" height="200%">
              <feGaussianBlur stdDeviation="1.25" result="blurred" />
              <feMerge>
                <feMergeNode in="blurred" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
          ))}
        </defs>

        <rect x="0" y="0" width={width} height={height} rx="14" fill="rgba(6,5,4,0.58)" />

        {[0, 50, 100].map((tick) => {
          const x = chartLeft + (tick / 100) * chartWidth;
          return (
            <g key={tick}>
              <line
                x1={x}
                y1={topPadding - 2}
                x2={x}
                y2={height - bottomPadding + 1}
                stroke="rgba(255,255,255,0.06)"
                strokeWidth="1"
                strokeDasharray="4 6"
              />
              <text
                x={x}
                y={height - 4}
                textAnchor="middle"
                fontSize="8"
                fill="rgba(255,255,255,0.34)"
                letterSpacing="0.12em"
              >
                {tick}
              </text>
            </g>
          );
        })}

        {traces.map(({ lane, baseline, d, end }, index) => {
          const highlighted = lane.label === dominantLane;
          return (
            <g key={lane.key}>
              <line
                x1={chartLeft}
                y1={baseline}
                x2={chartRight}
                y2={baseline}
                stroke="rgba(255,255,255,0.08)"
                strokeWidth="1"
              />
              <text
                x="12"
                y={baseline - 4}
                fontSize="9"
                fill={highlighted ? lane.fill : 'rgba(255,255,255,0.68)'}
                letterSpacing="0.18em"
              >
                {lane.label}
              </text>
              <text
                x="12"
                y={baseline + 8}
                fontSize="12"
                fill={highlighted ? '#fff1f4' : 'rgba(255,255,255,0.86)'}
                fontWeight="700"
              >
                {lane.value.toFixed(1)}%
              </text>
              <path
                d={d}
                fill="none"
                stroke={lane.fill}
                strokeOpacity={highlighted ? 1 : 0.7}
                strokeWidth={highlighted ? 1.12 : 0.82}
                strokeLinecap="round"
                strokeLinejoin="round"
                filter={highlighted ? `url(#heartbeat-glow-${graphId}-${lane.key})` : undefined}
              />
              <path
                d={d}
                fill="none"
                stroke="#fff7fb"
                strokeOpacity={highlighted ? 0.92 : 0.52}
                strokeWidth={highlighted ? 0.7 : 0.46}
                strokeLinecap="round"
                strokeLinejoin="round"
                pathLength={100}
                strokeDasharray="14 86"
                filter={highlighted ? `url(#heartbeat-glow-${graphId}-${lane.key})` : undefined}
              >
                {highlighted ? (
                  <animate
                    attributeName="stroke-dashoffset"
                    from="100"
                    to="0"
                    dur="1.75s"
                    repeatCount="indefinite"
                  />
                ) : null}
              </path>
              <circle
                cx={end.x}
                cy={end.y}
                r={highlighted ? 1.8 : 1.3}
                fill={lane.fill}
                fillOpacity={0.95}
              >
                {highlighted ? (
                  <animate
                    attributeName="r"
                    values="1.8;2.25;1.8"
                    dur="1.5s"
                    repeatCount="indefinite"
                  />
                ) : null}
              </circle>
              {highlighted ? (
                <rect
                  x={chartRight + 8}
                  y={baseline - 8}
                  width="32"
                  height="14"
                  rx="4"
                  fill="rgba(255,0,55,0.10)"
                />
              ) : null}
              <text
                x={chartRight + 24}
                y={baseline + 1}
                textAnchor="middle"
                fontSize="7"
                fill={highlighted ? lane.fill : 'rgba(255,255,255,0.34)'}
                letterSpacing="0.16em"
              >
                {highlighted ? 'LIVE' : `${index + 1}`}
              </text>
            </g>
          );
        })}
      </svg>
    </div>
  );
};
