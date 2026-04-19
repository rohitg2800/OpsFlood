// Central API config for the frontend.
// Configure with Vite env: VITE_API_BASE_URL (example: http://localhost:8000)

function stripTrailingSlash(url: string): string {
  return url.replace(/\/+$/, '');
}

function normalizeApiBaseUrl(url: string): string {
  const trimmed = url.trim();
  if (!trimmed) return '';
  if (trimmed === '/' || trimmed === './') return '';
  if (trimmed.startsWith('/')) return stripTrailingSlash(trimmed);
  if (/^https?:\/\//i.test(trimmed)) return stripTrailingSlash(trimmed);
  return `https://${stripTrailingSlash(trimmed)}`;
}

export const API_BASE_URL: string = (() => {
  const raw = import.meta.env.VITE_API_BASE_URL;
  if (typeof raw === 'string' && raw.trim()) return normalizeApiBaseUrl(raw);
  // Local dev uses the standalone FastAPI server. Production defaults to same-origin.
  return import.meta.env.DEV ? 'http://localhost:8000' : '';
})();

export function apiUrl(path: string): string {
  const p = path.startsWith('/') ? path : `/${path}`;
  return `${API_BASE_URL}${p}`;
}
