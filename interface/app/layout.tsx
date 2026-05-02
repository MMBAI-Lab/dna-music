import type { Metadata } from "next";
import "./globals.css";
import Nav from "@/components/Nav";
import Footer from "@/components/Footer";

export const metadata: Metadata = {
  title: {
    default: "DNA → Music · DansLab",
    template: "%s · DNA → Music",
  },
  description:
    "Interactive sonification of DNA tetranucleotide dynamics. Built on the aprox7 algorithm of the ABC Musica Molla project (DansLab, Universidad de la República).",
  openGraph: {
    title: "DNA → Music · DansLab",
    description:
      "Turn a DNA sequence into music — major-groove drives Soprano + Alto, minor-groove drives Tenor + Bass, with lookahead-corrected harmonic voices.",
    type: "website",
  },
};

// Read saved theme (or fall back to dark) and apply it on <html> before
// React hydrates, to avoid a flash of the wrong theme.
const themeBootstrap = `
(function(){
  try {
    var t = localStorage.getItem('theme');
    if (t !== 'light' && t !== 'dark') t = 'dark';
    document.documentElement.setAttribute('data-theme', t);
  } catch (_) {
    document.documentElement.setAttribute('data-theme', 'dark');
  }
})();`;

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" data-theme="dark" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeBootstrap }} />
      </head>
      <body
        className="flex min-h-screen flex-col"
        suppressHydrationWarning
      >
        <Nav />
        <main className="flex-1">{children}</main>
        <Footer />
      </body>
    </html>
  );
}
