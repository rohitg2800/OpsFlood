// Central API config for the frontend.
// Configure with Vite env: VITE_API_BASE_URL (example: http://localhost:8000)

function stripTrailingSlash(url: string): string {
  return url.replace(/\/+$/, '');
}

export const API_BASE_URL: string = (() => {
  const raw = import.meta.env.VITE_API_BASE_URL;
  if (typeof raw === 'string' && raw.trim()) return stripTrailingSlash(raw.trim());
  // Local backend default (FastAPI)
  return 'http://localhost:8000';
})();

export function apiUrl(path: string): string {
  const p = path.startsWith('/') ? path : `/${path}`;
  return `${API_BASE_URL}${p}`;
}
