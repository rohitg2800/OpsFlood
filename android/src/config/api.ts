// Central API config — mirrors frontend/src/config/api.ts
// Change BASE_URL to your Render deployment or local dev server.
export const API_BASE_URL = 'https://opsflood.onrender.com';

export function apiUrl(path: string): string {
  const p = path.startsWith('/') ? path : `/${path}`;
  return `${API_BASE_URL}${p}`;
}
