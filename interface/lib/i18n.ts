export type Lang = "en" | "es";

export const LANGS: Lang[] = ["en", "es"];

export function langPrefix(lang: Lang): string {
  return lang === "en" ? "" : `/${lang}`;
}

export function langHome(lang: Lang): string {
  return lang === "en" ? "/" : `/${lang}/`;
}

/** Build a path under the given language, preserving the section path. */
export function localizePath(lang: Lang, path: string): string {
  const clean = path.replace(/^\/+/, "").replace(/^(en|es)(\/|$)/, "");
  return lang === "en" ? `/${clean}` : `/${lang}/${clean}`;
}

/** Detect the active language from a pathname. */
export function detectLang(pathname: string): Lang {
  return pathname.startsWith("/es") ? "es" : "en";
}
