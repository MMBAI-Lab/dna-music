const BASE = process.env.NEXT_PUBLIC_BASE_PATH || "";

export function asset(path: string): string {
  if (!path) return path;
  if (!path.startsWith("/")) return path;
  if (BASE && path.startsWith(BASE + "/")) return path;
  return `${BASE}${path}`;
}
