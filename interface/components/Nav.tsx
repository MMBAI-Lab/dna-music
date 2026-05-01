"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import ThemeToggle from "@/components/ThemeToggle";
import LangSwitch from "@/components/LangSwitch";
import { detectLang, langHome } from "@/lib/i18n";

export default function Nav() {
  const pathname = usePathname() || "/";
  const lang = detectLang(pathname);
  const home = langHome(lang);
  const labLink = "https://danslab.xyz/outreach/sonification/";
  const labLabel = lang === "es" ? "Web del laboratorio" : "Lab website";

  return (
    <header className="sticky top-0 z-50 border-b border-border bg-bg/80 backdrop-blur-md">
      <nav className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <Link
          href={home}
          className="flex items-baseline gap-3 text-ink hover:text-accent"
        >
          <span className="font-serif text-xl font-semibold tracking-tight">
            DNA → Music
          </span>
          <span className="hidden text-xs uppercase tracking-[0.25em] text-subtle md:inline">
            DansLab · MMBAI
          </span>
        </Link>
        <div className="flex items-center gap-3 md:gap-4">
          <a
            href={labLink}
            target="_blank"
            rel="noreferrer"
            className="hidden text-sm font-medium text-muted hover:text-ink md:inline"
          >
            {labLabel} →
          </a>
          <LangSwitch />
          <ThemeToggle />
        </div>
      </nav>
    </header>
  );
}
