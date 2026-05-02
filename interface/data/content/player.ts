import type { Lang } from "@/lib/i18n";

// Short labels for the scale toggles (must fit on a switch face).
// Universal — same in both languages.
export const SCALE_ABBREV: Record<string, string> = {
  d_minor: "Dm",
  g_minor: "Gm",
  c_minor: "Cm",
  a_minor: "Am",
  e_minor: "Em",
  d_major: "D",
  a_major: "A",
  d_phrygian: "Dφ",
  d_min_pent: "Pm",
  d_maj_pent: "PM",
};

export const PLAYER: Record<Lang, {
  back: string;
  eyebrow: string;
  title: string;
  lede: string;
  console_heading: string;
  console_subtitle: string;
  seq_label: string;
  seq_placeholder: string;
  seq_hint: (count: number, max: number) => string;
  scale_label: string;
  scale_active: string;
  scales: Record<string, string>;
  bpm_label: string;
  bpm_unit: string;
  generate: string;
  generating: string;
  status_loading: string;
  status_ready: string;
  status_error: (msg: string) => string;
  status_done: (n: number, dur: string, bpm: number) => string;
  player_heading: string;
  play: string;
  stop: string;
  download: string;
  stat_tetras: string;
  stat_duration: string;
  stat_bases: string;
  stat_ab_diss: string;
  stat_alto_semi: string;
  sample_heading: string;
  algo_heading: string;
  algo_paragraphs: string[];
  algo_link_label: string;
  algo_link_href: string;
}> = {
  en: {
    back: "← Lab website",
    eyebrow: "DNA → Music · aprox7",
    title: "Sonify a DNA sequence",
    lede:
      "Each tetranucleotide is mapped to a four-voice chord (SATB). Soprano and Bass come from the major and minor groove dynamics; Alto and Tenor are generated to maximise harmonic consonance — with one-step lookahead so transitions sound smooth.",
    console_heading: "DNA → Music · console",
    console_subtitle: "aprox7",
    seq_label: "Sequence",
    seq_placeholder:
      "Paste your sequence here (A, T, C, G) — max. 200 bases\nExample: GCAACGTGCTATGGAAGCGCAATAAGTACC",
    seq_hint: (count, max) =>
      `Only A, T, C, G letters are used · minimum 4 bases · ${count} / ${max}`,
    scale_label: "Key",
    scale_active: "Active",
    scales: {
      d_minor: "D natural minor",
      g_minor: "G natural minor",
      c_minor: "C natural minor",
      a_minor: "A minor / C major",
      e_minor: "E minor / G major",
      d_major: "D major",
      a_major: "A major",
      d_phrygian: "D Phrygian (flamenco)",
      d_min_pent: "D minor pentatonic",
      d_maj_pent: "D major pentatonic",
    },
    bpm_label: "Tempo",
    bpm_unit: "BPM",
    generate: "Generate music",
    generating: "Generating…",
    status_loading: "Loading data…",
    status_ready: "Ready. Paste your sequence and click Generate.",
    status_error: (msg) => `Error: ${msg}`,
    status_done: (n, dur, bpm) =>
      `Generated ${n} notes · ${dur} at ${bpm} BPM`,
    player_heading: "Result",
    play: "▶ Play",
    stop: "■ Stop",
    download: "⬇ Download MIDI",
    stat_tetras: "Tetranucleotides",
    stat_duration: "Estimated duration",
    stat_bases: "Bases processed",
    stat_ab_diss: "A–B dissonances",
    stat_alto_semi: "Alto semitones",
    sample_heading: "First 8 chords",
    algo_heading: "How it works",
    algo_paragraphs: [
      "DNA double-helix grooves (major and minor) open and close dynamically. Their mean lifetimes and event rates were measured from molecular dynamics simulations for each unique tetranucleotide and mapped to pitch and duration.",
      "Soprano follows the major-groove pitch; Bass follows the minor-groove pitch. Alto and Tenor are picked from the active scale to maximise consonance with the Bass, both at the current step and the next (lookahead +1). Semitones, tritones, parallel fifths and octaves are penalised; contrary motion is rewarded.",
      "Soprano + Alto share the major-groove duration; Tenor + Bass share the minor-groove duration — two rhythmically independent duets that overlap.",
    ],
    algo_link_label: "Read the full sonification page",
    algo_link_href: "https://danslab.xyz/outreach/sonification/",
  },
  es: {
    back: "← Web del laboratorio",
    eyebrow: "ADN → Música · aprox7",
    title: "Sonifica una secuencia de ADN",
    lede:
      "Cada tetranucleótido se asigna a un acorde a cuatro voces (SATB). Soprano y Bajo provienen de la dinámica de los surcos mayor y menor; Alto y Tenor se generan para maximizar la consonancia armónica — con anticipación de un paso para que las transiciones suenen suaves.",
    console_heading: "ADN → Música · consola",
    console_subtitle: "aprox7",
    seq_label: "Secuencia",
    seq_placeholder:
      "Pega tu secuencia aquí (A, T, C, G) — máx. 200 bases\nEjemplo: GCAACGTGCTATGGAAGCGCAATAAGTACC",
    seq_hint: (count, max) =>
      `Solo se usan las letras A, T, C, G · mínimo 4 bases · ${count} / ${max}`,
    scale_label: "Tonalidad",
    scale_active: "Activa",
    scales: {
      d_minor: "Re menor natural",
      g_minor: "Sol menor natural",
      c_minor: "Do menor natural",
      a_minor: "La menor / Do mayor",
      e_minor: "Mi menor / Sol mayor",
      d_major: "Re mayor",
      a_major: "La mayor",
      d_phrygian: "Re frigio (flamenco)",
      d_min_pent: "Pentatónica menor de Re",
      d_maj_pent: "Pentatónica mayor de Re",
    },
    bpm_label: "Tempo",
    bpm_unit: "BPM",
    generate: "Generar música",
    generating: "Generando…",
    status_loading: "Cargando datos…",
    status_ready: "Listo. Pega tu secuencia y pulsa Generar.",
    status_error: (msg) => `Error: ${msg}`,
    status_done: (n, dur, bpm) =>
      `Generadas ${n} notas · ${dur} a ${bpm} BPM`,
    player_heading: "Resultado",
    play: "▶ Reproducir",
    stop: "■ Detener",
    download: "⬇ Descargar MIDI",
    stat_tetras: "Tetranucleótidos",
    stat_duration: "Duración estimada",
    stat_bases: "Bases procesadas",
    stat_ab_diss: "Disonancias A–B",
    stat_alto_semi: "Semitonos en Alto",
    sample_heading: "Primeros 8 acordes",
    algo_heading: "Cómo funciona",
    algo_paragraphs: [
      "Los surcos mayor y menor de la doble hélice de ADN se abren y cierran dinámicamente. Sus tiempos de vida medios y frecuencias se midieron en simulaciones de dinámica molecular para cada tetranucleótido único y se trasladaron a tono y duración.",
      "La Soprano sigue el tono del surco mayor; el Bajo, el del surco menor. Alto y Tenor se eligen dentro de la escala activa maximizando la consonancia con el Bajo, en el paso actual y en el siguiente (lookahead +1). Se penalizan semitonos, tritonos y quintas/octavas paralelas; se premia el movimiento contrario.",
      "Soprano + Alto comparten la duración del surco mayor; Tenor + Bajo comparten la del surco menor — dos dúos rítmicamente independientes que se superponen.",
    ],
    algo_link_label: "Más información en la página del laboratorio",
    algo_link_href: "https://danslab.xyz/es/outreach/sonification/",
  },
};
