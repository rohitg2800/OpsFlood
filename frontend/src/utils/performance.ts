export function isLiteMotionDevice(): boolean {
  if (typeof window === 'undefined') {
    return false;
  }

  const nav = navigator as Navigator & { deviceMemory?: number };
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const constrainedCpu =
    typeof nav.hardwareConcurrency === 'number' && nav.hardwareConcurrency > 0 && nav.hardwareConcurrency <= 6;
  const constrainedMemory =
    typeof nav.deviceMemory === 'number' && nav.deviceMemory > 0 && nav.deviceMemory <= 6;

  return prefersReducedMotion || constrainedCpu || constrainedMemory;
}
