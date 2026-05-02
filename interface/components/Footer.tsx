"use client";

import { usePathname } from "next/navigation";
import { detectLang } from "@/lib/i18n";

const STRINGS = {
  en: {
    rights: "DansLab — Molecular Modeling, Bioinformatics & AI",
    affiliation: "Universidad de la República, Uruguay",
    project: "DNA-music project · Pablo D. Dans & Nicolás Molla",
  },
  es: {
    rights: "DansLab — Modelado Molecular, Bioinformática e IA",
    affiliation: "Universidad de la República, Uruguay",
    project: "Proyecto DNA-music · Pablo D. Dans y Nicolás Molla",
  },
} as const;

export default function Footer() {
  const pathname = usePathname() || "/";
  const lang = detectLang(pathname);
  const dict = STRINGS[lang];
  return (
    <footer className="relative z-10 border-t border-border bg-bg">
      <div className="mx-auto flex max-w-6xl flex-col items-start justify-between gap-3 px-6 py-10 text-sm text-muted md:flex-row md:items-center">
        <p>
          © {new Date().getFullYear()} {dict.rights}
        </p>
        <p>{dict.project}</p>
        <p>{dict.affiliation}</p>
      </div>
    </footer>
  );
}
