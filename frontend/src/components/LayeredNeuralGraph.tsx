import React, { useId, useMemo } from 'react';

export interface NeuralLaneNode {
  key: string;
  label: string;
  shortLabel?: string;
  value: number;
  fill: string;
}

interface LayeredNeuralGraphProps {
  lanes: NeuralLaneNode[];
  preferredLabel: string;
  compact?: boolean;
  className?: string;
}

interface GraphNode extends NeuralLaneNode {
  x: number;
  y: number;
  radius: number;
  activation: number;
  isPreferred: boolean;
  order: number;
}

interface HiddenNode {
  key: string;
  x: number;
  y: number;
  radius: number;
  activation: number;
  isPreferred: boolean;
  order: number;
}

interface ThreadPath {
  key: string;
  d: string;
  stroke: string;
  strokeOpacity: number;
  strokeWidth: number;
  emphasized: boolean;
}

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

const distribute = (count: number, start: number, end: number) => {
  if (count <= 1) return [(start + end) / 2];
  return Array.from({ length: count }, (_, index) => start + (index / (count - 1)) * (end - start));
};

const interpolate = (values: number[], anchor: number) => {
  if (!values.length) return 0;
  const lower = Math.floor(anchor);
  const upper = Math.min(values.length - 1, Math.ceil(anchor));
  const blend = anchor - lower;
  const start = values[lower] ?? values[0] ?? 0;
  const end = values[upper] ?? start;
  return start + (end - start) * blend;
};

const curveBetween = (x1: number, y1: number, x2: number, y2: number) => {
  const delta = x2 - x1;
  const controlA = x1 + delta * 0.38;
  const controlB = x1 + delta * 0.62;
  return `M ${x1} ${y1} C ${controlA} ${y1}, ${controlB} ${y2}, ${x2} ${y2}`;
};

export const LayeredNeuralGraph: React.FC<LayeredNeuralGraphProps> = ({
  lanes,
  preferredLabel,
  compact = false,
  className = '',
}) => {
  const safeId = useId().replace(/:/g, '');
  const pulseMs = compact ? 2.1 : 1.8;
  const width = compact ? 468 : 612;
  const height = compact ? 244 : 308;
  const inputLeadX = compact ? 18 : 24;
  const outputTrailX = compact ? width - 18 : width - 22;
  const inputX = compact ? 86 : 110;
  const hiddenAX = compact ? 198 : 264;
  const hiddenBX = compact ? 292 : 392;
  const outputX = compact ? 388 : 514;
  const topLabelY = compact ? 18 : 22;
  const nodeTop = compact ? 54 : 68;
  const nodeBottom = compact ? height - 34 : height - 44;

  const preferredIndex = Math.max(0, lanes.findIndex((lane) => lane.label === preferredLabel));
  const preferredLane = lanes[preferredIndex] || lanes[0];
  const laneValues = lanes.map((lane) => lane.value);
  const inputYPositions = distribute(lanes.length, nodeTop, nodeBottom);
  const hiddenAYPositions = distribute(compact ? 6 : 7, nodeTop - 6, nodeBottom + 6);
  const hiddenBYPositions = distribute(compact ? 5 : 6, nodeTop, nodeBottom);
  const outputYPositions = distribute(lanes.length, nodeTop, nodeBottom);
  const preferredAnchorA = preferredIndex * ((hiddenAYPositions.length - 1) / Math.max(lanes.length - 1, 1));
  const preferredAnchorB = preferredIndex * ((hiddenBYPositions.length - 1) / Math.max(lanes.length - 1, 1));

  const inputNodes: GraphNode[] = lanes.map((lane, index) => ({
    ...lane,
    x: inputX,
    y: inputYPositions[index],
    radius: compact ? 7 + lane.value / 28 : 9 + lane.value / 24,
    activation: lane.value,
    isPreferred: index === preferredIndex,
    order: index,
  }));

  const hiddenANodes: HiddenNode[] = hiddenAYPositions.map((y, index) => {
    const anchor = index * ((lanes.length - 1) / Math.max(hiddenAYPositions.length - 1, 1));
    const distance = Math.abs(index - preferredAnchorA);
    const corridor = Math.max(0, 1 - distance / 2.2);
    const activation = clamp(
      interpolate(laneValues, anchor) * 0.72 + preferredLane.value * corridor * 0.24 + 12,
      8,
      100,
    );

    return {
      key: `hidden-a-${index}`,
      x: hiddenAX,
      y,
      radius: compact ? 5.4 + activation / 34 : 6.4 + activation / 28,
      activation,
      isPreferred: distance <= 1.15,
      order: index,
    };
  });

  const hiddenBValues = hiddenANodes.map((node) => node.activation);
  const hiddenBNodes: HiddenNode[] = hiddenBYPositions.map((y, index) => {
    const anchor = index * ((hiddenBValues.length - 1) / Math.max(hiddenBYPositions.length - 1, 1));
    const distance = Math.abs(index - preferredAnchorB);
    const corridor = Math.max(0, 1 - distance / 1.9);
    const activation = clamp(
      interpolate(hiddenBValues, anchor) * 0.76 + preferredLane.value * corridor * 0.2 + 9,
      8,
      100,
    );

    return {
      key: `hidden-b-${index}`,
      x: hiddenBX,
      y,
      radius: compact ? 5.1 + activation / 36 : 6.1 + activation / 30,
      activation,
      isPreferred: distance <= 1.05,
      order: index,
    };
  });

  const outputNodes: GraphNode[] = lanes.map((lane, index) => ({
    ...lane,
    x: outputX,
    y: outputYPositions[index],
    radius: compact ? 7.6 + lane.value / 24 : 9.4 + lane.value / 20,
    activation: lane.value,
    isPreferred: index === preferredIndex,
    order: index,
  }));

  const primaryHiddenANode =
    hiddenANodes
      .filter((node) => node.isPreferred)
      .sort((left, right) => right.activation - left.activation)[0] ||
    hiddenANodes[Math.round(preferredAnchorA)] ||
    hiddenANodes[0];

  const primaryHiddenBNode =
    hiddenBNodes
      .filter((node) => node.isPreferred)
      .sort((left, right) => right.activation - left.activation)[0] ||
    hiddenBNodes[Math.round(preferredAnchorB)] ||
    hiddenBNodes[0];

  const secondaryHiddenANode = hiddenANodes.find(
    (node) => node.isPreferred && node.key !== primaryHiddenANode?.key,
  );

  const secondaryHiddenBNode = hiddenBNodes.find(
    (node) => node.isPreferred && node.key !== primaryHiddenBNode?.key,
  );

  const preferredInputNode = inputNodes[preferredIndex] || inputNodes[0];
  const preferredOutputNode = outputNodes[preferredIndex] || outputNodes[0];

  const inputToHiddenA: ThreadPath[] = useMemo(
    () =>
      inputNodes.flatMap((source) =>
        hiddenANodes.map((target) => {
          const emphasis = source.isPreferred || target.isPreferred;
          const intensity = clamp((source.activation + target.activation) / 160, 0.12, 1);
          return {
            key: `${source.key}-${target.key}`,
            d: curveBetween(source.x + source.radius, source.y, target.x - target.radius, target.y),
            stroke: emphasis ? preferredLane.fill : '#ffffff',
            strokeOpacity: emphasis ? 0.18 + intensity * 0.32 : 0.06 + intensity * 0.14,
            strokeWidth: emphasis ? 1.3 + intensity * 0.75 : 0.6 + intensity * 0.45,
            emphasized: emphasis,
          };
        }),
      ),
    [hiddenANodes, inputNodes, preferredLane.fill],
  );

  const hiddenAToHiddenB: ThreadPath[] = useMemo(
    () =>
      hiddenANodes.flatMap((source) =>
        hiddenBNodes.map((target) => {
          const emphasis = source.isPreferred || target.isPreferred;
          const shared = clamp((source.activation + target.activation) / 180, 0.1, 1);
          return {
            key: `${source.key}-${target.key}`,
            d: curveBetween(source.x + source.radius, source.y, target.x - target.radius, target.y),
            stroke: emphasis ? preferredLane.fill : '#ffffff',
            strokeOpacity: emphasis ? 0.16 + shared * 0.34 : 0.05 + shared * 0.12,
            strokeWidth: emphasis ? 1.15 + shared * 0.62 : 0.55 + shared * 0.42,
            emphasized: emphasis,
          };
        }),
      ),
    [hiddenANodes, hiddenBNodes, preferredLane.fill],
  );

  const hiddenBToOutput: ThreadPath[] = useMemo(
    () =>
      hiddenBNodes.flatMap((source) =>
        outputNodes.map((target) => {
          const emphasis = source.isPreferred || target.isPreferred;
          const intensity = clamp((source.activation + target.activation) / 170, 0.12, 1);
          return {
            key: `${source.key}-${target.key}`,
            d: curveBetween(source.x + source.radius, source.y, target.x - target.radius, target.y),
            stroke: emphasis ? target.fill : '#ffffff',
            strokeOpacity: emphasis ? 0.16 + intensity * 0.36 : 0.05 + intensity * 0.14,
            strokeWidth: emphasis ? 1.2 + intensity * 0.7 : 0.58 + intensity * 0.44,
            emphasized: emphasis,
          };
        }),
      ),
    [hiddenBNodes, outputNodes],
  );

  const allThreads = useMemo(
    () => [...inputToHiddenA, ...hiddenAToHiddenB, ...hiddenBToOutput],
    [hiddenAToHiddenB, hiddenBToOutput, inputToHiddenA],
  );

  const animatedThreadKeys = useMemo(() => {
    const keys = new Set<string>();

    if (preferredInputNode && primaryHiddenANode) {
      keys.add(`${preferredInputNode.key}-${primaryHiddenANode.key}`);
    }
    if (primaryHiddenANode && primaryHiddenBNode) {
      keys.add(`${primaryHiddenANode.key}-${primaryHiddenBNode.key}`);
    }
    if (primaryHiddenBNode && preferredOutputNode) {
      keys.add(`${primaryHiddenBNode.key}-${preferredOutputNode.key}`);
    }

    if (preferredInputNode && secondaryHiddenANode) {
      keys.add(`${preferredInputNode.key}-${secondaryHiddenANode.key}`);
    }
    if (secondaryHiddenANode && primaryHiddenBNode) {
      keys.add(`${secondaryHiddenANode.key}-${primaryHiddenBNode.key}`);
    }
    if (secondaryHiddenBNode && preferredOutputNode) {
      keys.add(`${secondaryHiddenBNode.key}-${preferredOutputNode.key}`);
    }

    return keys;
  }, [
    preferredInputNode,
    preferredOutputNode,
    primaryHiddenANode,
    primaryHiddenBNode,
    secondaryHiddenANode,
    secondaryHiddenBNode,
  ]);

  return (
    <div className={className}>
      <svg viewBox={`0 0 ${width} ${height}`} className="h-full w-full" aria-hidden="true">
        <defs>
          <radialGradient id={`${safeId}-backdrop`} cx="50%" cy="50%" r="65%">
            <stop offset="0%" stopColor="rgba(255,255,255,0.08)" />
            <stop offset="52%" stopColor="rgba(255,255,255,0.02)" />
            <stop offset="100%" stopColor="rgba(255,255,255,0)" />
          </radialGradient>
          <radialGradient id={`${safeId}-preferred-core`} cx="50%" cy="50%" r="70%">
            <stop offset="0%" stopColor="#fff6f8" />
            <stop offset="45%" stopColor={preferredLane.fill} stopOpacity="0.95" />
            <stop offset="100%" stopColor={preferredLane.fill} stopOpacity="0.2" />
          </radialGradient>
          <filter id={`${safeId}-soft-glow`} x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur stdDeviation="4.5" result="blurred" />
            <feMerge>
              <feMergeNode in="blurred" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
          <filter id={`${safeId}-thread-glow`} x="-60%" y="-60%" width="220%" height="220%">
            <feGaussianBlur stdDeviation="2.8" result="threadGlow" />
            <feMerge>
              <feMergeNode in="threadGlow" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>

        <rect x="0" y="0" width={width} height={height} rx={compact ? 16 : 20} fill={`url(#${safeId}-backdrop)`} />

        <text x={inputX} y={topLabelY} textAnchor="middle" fontSize={compact ? 9 : 11} fill="rgba(255,255,255,0.56)" letterSpacing="0.18em">
          INPUT
        </text>
        <text x={(hiddenAX + hiddenBX) / 2} y={topLabelY} textAnchor="middle" fontSize={compact ? 9 : 11} fill="rgba(255,255,255,0.56)" letterSpacing="0.18em">
          HIDDEN STACK
        </text>
        <text x={outputX} y={topLabelY} textAnchor="middle" fontSize={compact ? 9 : 11} fill="rgba(255,255,255,0.56)" letterSpacing="0.18em">
          OUTPUT
        </text>

        {inputNodes.map((node) => (
          <g key={`input-lead-${node.key}`}>
            <line
              x1={inputLeadX}
              y1={node.y}
              x2={node.x - node.radius - 12}
              y2={node.y}
              stroke={node.isPreferred ? node.fill : 'rgba(255,255,255,0.42)'}
              strokeOpacity={node.isPreferred ? 0.88 : 0.4}
              strokeWidth={node.isPreferred ? 2 : 1.2}
              strokeLinecap="round"
            />
            <text
              x={inputLeadX}
              y={node.y - 10}
              textAnchor="start"
              fontSize={compact ? 8 : 10}
              fill={node.isPreferred ? node.fill : 'rgba(255,255,255,0.7)'}
              letterSpacing="0.12em"
            >
              {node.shortLabel || node.label}
            </text>
          </g>
        ))}

        {allThreads.map((thread) => (
          <path
            key={thread.key}
            d={thread.d}
            fill="none"
            stroke={thread.stroke}
            strokeOpacity={thread.strokeOpacity}
            strokeWidth={thread.strokeWidth}
            strokeLinecap="round"
          />
        ))}

        {allThreads
          .filter((thread) => animatedThreadKeys.has(thread.key))
          .map((thread, index) => (
            <path
              key={`${thread.key}-live`}
              d={thread.d}
              fill="none"
              stroke="#fff6fb"
              strokeOpacity={0.82}
              strokeWidth={Math.max(0.9, thread.strokeWidth * 0.58)}
              strokeLinecap="round"
              pathLength={100}
              strokeDasharray={compact ? '11 89' : '13 87'}
              filter={`url(#${safeId}-thread-glow)`}
            >
              <animate
                attributeName="stroke-dashoffset"
                from="100"
                to="0"
                dur={`${pulseMs + index * 0.03}s`}
                repeatCount="indefinite"
              />
            </path>
          ))}

        {inputNodes.map((node) => (
          <g key={node.key}>
            <circle
              cx={node.x}
              cy={node.y}
              r={node.radius + 3}
              fill={node.isPreferred ? node.fill : '#ffffff'}
              fillOpacity={node.isPreferred ? 0.1 : 0.03}
            >
              {node.key === preferredInputNode?.key ? (
                <animate
                  attributeName="r"
                  values={`${node.radius + 2.2};${node.radius + 4.8};${node.radius + 2.2}`}
                  dur={`${pulseMs}s`}
                  repeatCount="indefinite"
                />
              ) : null}
            </circle>
            <circle
              cx={node.x}
              cy={node.y}
              r={node.radius}
              fill="rgba(8,8,8,0.72)"
              stroke={node.isPreferred ? node.fill : 'rgba(255,255,255,0.7)'}
              strokeWidth={node.isPreferred ? 1.8 : 1.2}
              filter={node.isPreferred ? `url(#${safeId}-soft-glow)` : undefined}
            >
              {node.key === preferredInputNode?.key ? (
                <animate
                  attributeName="stroke-opacity"
                  values="0.78;1;0.78"
                  dur={`${pulseMs}s`}
                  repeatCount="indefinite"
                />
              ) : null}
            </circle>
            <circle
              cx={node.x}
              cy={node.y}
              r={Math.max(2.4, node.radius * 0.34)}
              fill={node.isPreferred ? `url(#${safeId}-preferred-core)` : 'rgba(255,255,255,0.72)'}
            >
              {node.key === preferredInputNode?.key ? (
                <animate
                  attributeName="r"
                  values={`${Math.max(2.4, node.radius * 0.3)};${Math.max(3.2, node.radius * 0.44)};${Math.max(2.4, node.radius * 0.3)}`}
                  dur={`${pulseMs}s`}
                  repeatCount="indefinite"
                />
              ) : null}
            </circle>
          </g>
        ))}

        {hiddenANodes.map((node) => (
          <g key={node.key}>
            <circle
              cx={node.x}
              cy={node.y}
              r={node.radius + 2}
              fill={node.isPreferred ? preferredLane.fill : '#ffffff'}
              fillOpacity={node.isPreferred ? 0.08 : 0.025}
            >
              {node.key === primaryHiddenANode?.key ? (
                <animate
                  attributeName="fill-opacity"
                  values="0.06;0.14;0.06"
                  dur={`${pulseMs}s`}
                  repeatCount="indefinite"
                />
              ) : null}
            </circle>
            <circle
              cx={node.x}
              cy={node.y}
              r={node.radius}
              fill="rgba(8,8,8,0.72)"
              stroke={node.isPreferred ? preferredLane.fill : 'rgba(255,255,255,0.42)'}
              strokeWidth={node.isPreferred ? 1.55 : 1}
            >
              {node.key === primaryHiddenANode?.key ? (
                <animate
                  attributeName="stroke-opacity"
                  values="0.75;1;0.75"
                  dur={`${pulseMs}s`}
                  repeatCount="indefinite"
                />
              ) : null}
            </circle>
            <circle
              cx={node.x}
              cy={node.y}
              r={Math.max(2, node.radius * 0.28)}
              fill={node.isPreferred ? preferredLane.fill : 'rgba(255,255,255,0.42)'}
              fillOpacity={node.isPreferred ? 0.85 : 0.42}
            >
              {node.key === primaryHiddenANode?.key ? (
                <animate
                  attributeName="r"
                  values={`${Math.max(2, node.radius * 0.24)};${Math.max(2.8, node.radius * 0.38)};${Math.max(2, node.radius * 0.24)}`}
                  dur={`${pulseMs}s`}
                  repeatCount="indefinite"
                />
              ) : null}
            </circle>
          </g>
        ))}

        {hiddenBNodes.map((node) => (
          <g key={node.key}>
            <circle
              cx={node.x}
              cy={node.y}
              r={node.radius + 2}
              fill={node.isPreferred ? preferredLane.fill : '#ffffff'}
              fillOpacity={node.isPreferred ? 0.09 : 0.03}
            >
              {node.key === primaryHiddenBNode?.key ? (
                <animate
                  attributeName="fill-opacity"
                  values="0.06;0.15;0.06"
                  dur={`${pulseMs}s`}
                  repeatCount="indefinite"
                />
              ) : null}
            </circle>
            <circle
              cx={node.x}
              cy={node.y}
              r={node.radius}
              fill="rgba(8,8,8,0.72)"
              stroke={node.isPreferred ? preferredLane.fill : 'rgba(255,255,255,0.46)'}
              strokeWidth={node.isPreferred ? 1.6 : 1.05}
              filter={node.isPreferred ? `url(#${safeId}-soft-glow)` : undefined}
            >
              {node.key === primaryHiddenBNode?.key ? (
                <animate
                  attributeName="stroke-opacity"
                  values="0.78;1;0.78"
                  dur={`${pulseMs}s`}
                  repeatCount="indefinite"
                />
              ) : null}
            </circle>
            <circle
              cx={node.x}
              cy={node.y}
              r={Math.max(2, node.radius * 0.3)}
              fill={node.isPreferred ? preferredLane.fill : 'rgba(255,255,255,0.48)'}
              fillOpacity={node.isPreferred ? 0.92 : 0.44}
            >
              {node.key === primaryHiddenBNode?.key ? (
                <animate
                  attributeName="r"
                  values={`${Math.max(2, node.radius * 0.24)};${Math.max(2.8, node.radius * 0.38)};${Math.max(2, node.radius * 0.24)}`}
                  dur={`${pulseMs}s`}
                  repeatCount="indefinite"
                />
              ) : null}
            </circle>
          </g>
        ))}

        {outputNodes.map((node) => (
          <g key={`output-${node.key}`}>
            <circle
              cx={node.x}
              cy={node.y}
              r={node.radius + 3.5}
              fill={node.fill}
              fillOpacity={node.isPreferred ? 0.14 : 0.05}
            >
              {node.key === preferredOutputNode?.key ? (
                <animate
                  attributeName="r"
                  values={`${node.radius + 2.5};${node.radius + 5.8};${node.radius + 2.5}`}
                  dur={`${pulseMs}s`}
                  repeatCount="indefinite"
                />
              ) : null}
            </circle>
            <circle
              cx={node.x}
              cy={node.y}
              r={node.radius}
              fill="rgba(8,8,8,0.76)"
              stroke={node.fill}
              strokeOpacity={node.isPreferred ? 1 : 0.66}
              strokeWidth={node.isPreferred ? 2 : 1.3}
              filter={node.isPreferred ? `url(#${safeId}-soft-glow)` : undefined}
            >
              {node.key === preferredOutputNode?.key ? (
                <animate
                  attributeName="stroke-width"
                  values="2;2.7;2"
                  dur={`${pulseMs}s`}
                  repeatCount="indefinite"
                />
              ) : null}
            </circle>
            <circle
              cx={node.x}
              cy={node.y}
              r={Math.max(2.8, node.radius * 0.34)}
              fill={node.fill}
            >
              {node.key === preferredOutputNode?.key ? (
                <animate
                  attributeName="r"
                  values={`${Math.max(2.8, node.radius * 0.3)};${Math.max(3.6, node.radius * 0.42)};${Math.max(2.8, node.radius * 0.3)}`}
                  dur={`${pulseMs}s`}
                  repeatCount="indefinite"
                />
              ) : null}
            </circle>
            <line
              x1={node.x + node.radius}
              y1={node.y}
              x2={outputTrailX}
              y2={node.y}
              stroke={node.fill}
              strokeOpacity={node.isPreferred ? 0.78 : 0.28}
              strokeWidth={node.isPreferred ? 1.8 : 1}
              strokeLinecap="round"
            />
            <text
              x={outputTrailX - 2}
              y={node.y - 10}
              textAnchor="end"
              fontSize={compact ? 8 : 10}
              fill={node.isPreferred ? node.fill : 'rgba(255,255,255,0.66)'}
              letterSpacing="0.12em"
            >
              {node.shortLabel || node.label}
            </text>
          </g>
        ))}
      </svg>
    </div>
  );
};
