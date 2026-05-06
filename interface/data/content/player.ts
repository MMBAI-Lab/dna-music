import type { Lang } from "@/lib/i18n";

// Compact labels shown directly under each key toggle.
// Universal — same in both languages (use English "Minor/Major" idiom
// since these are music-theory standards regardless of UI language).
export const SCALE_ABBREV: Record<string, string> = {
  d_minor: "D Minor",
  g_minor: "G Minor",
  c_minor: "C Minor",
  a_minor: "A Minor",
  e_minor: "E Minor",
  d_major: "D Major",
  a_major: "A Major",
  d_phrygian: "D Phryg.",
  d_min_pent: "D m. pent",
  d_maj_pent: "D M. pent",
  d_dbl_harm: "D Dbl. h.",
  d_octatonic: "D Octat.",
};

export const PLAYER: Record<Lang, {
  back: string;
  eyebrow: string;
  title: string;
  lede: string;
  console_heading: string;
  seq_label: string;
  seq_placeholder: string;
  seq_hint: (count: number, max: number) => string;
  scale_label: string;
  scale_active: string;
  scales: Record<string, string>;
  tonal_label: string;
  chromatic_label: string;
  aprox_label: string;
  aprox_select_label: string;
  meter_label: string;
  meter_free: string;
  meter_44: string;
  aprox_active: string;
  aprox_full: (n: number) => string;
  aprox_descriptions: Record<5 | 6 | 7 | 8 | 9 | 10 | 11, string>;
  mix_label: string;
  mix_voice: { s: string; a: string; t: string; b: string };
  mix_voice_origin: { s: string; a: string; t: string; b: string };
  mix_voice_origin_10: { s: string; a: string; t: string; b: string };
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
  rewind: string;
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
    eyebrow: "DNA → Music · Approximation 5 to 7",
    title: "Sonify a DNA sequence",
    lede:
      "Each tetranucleotide is mapped to a four-voice chord (SATB). Soprano and Bass come from the major and minor groove dynamics; Alto and Tenor are generated to maximise harmonic consonance.",
    console_heading: "DNA → Music · console",
    seq_label: "Sequence",
    seq_placeholder:
      "Paste your sequence here (A, T, C, G) — max. 200 bases\nExample: GCAACGTGCTATGGAAGCGCAATAAGTACC",
    seq_hint: (count, max) =>
      `Only A, T, C, G letters are used · minimum 4 bases · ${count} / ${max}`,
    scale_label: "Key",
    scale_active: "Active",
    tonal_label: "Tonal",
    chromatic_label: "Chromatic (12-tone, no snap)",
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
      d_dbl_harm: "D Double harmonic (Byzantine)",
      d_octatonic: "D Octatonic (W–H, diminished)",
    },
    aprox_label: "Algorithm",
    aprox_select_label: "Select",
    meter_label: "Meter",
    meter_free: "Free",
    meter_44: "4/4",
    aprox_active: "Active",
    aprox_full: (n) => `Approximation ${n}`,
    aprox_descriptions: {
      5: "Linear duration · greedy harmonic cost · post-hoc S–A parallel fix",
      6: "Logarithmic duration · greedy harmonic cost · post-hoc S–A parallel fix",
      7: "Logarithmic duration · lookahead-aware cost (penalises semitones, tritones, parallels)",
      8: "Logarithmic duration · Bach/WTC-informed: stepwise preference, 3rds & 6ths, leap resolution, 2-step lookahead",
      9: "Logarithmic duration · WTC rhythmic normalisation (run homogenisation, max 2:1 transitions, binary groupings) · WTC voice leading",
      10: "Logarithmic duration · WTC voice leading · voice-role swap: T carries minor-groove data, B is the generated fix voice",
      11: "Logarithmic duration · S is a planned arch melody (climax at ~60 %, 2–4 leaps, direction-change rules, WTC intervals) · WTC voice leading for A, T, B",
    },
    mix_label: "Volume Mix",
    mix_voice: { s: "Soprano", a: "Alto", t: "Tenor", b: "Bass" },
    mix_voice_origin: {
      s: "Major groove",
      a: "Fix",
      t: "Fix",
      b: "Minor groove",
    },
    mix_voice_origin_10: {
      s: "Major groove",
      a: "Fix",
      t: "Minor groove",
      b: "Fix",
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
    rewind: "⏮ Restart",
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
      "Soprano follows the major-groove pitch; Bass follows the minor-groove pitch. Alto and Tenor are picked from the active scale to maximise consonance with the Bass.",
      "Five algorithm variants are available. Approximation 5 uses linear duration mapping and a greedy harmonic cost (motion + dissonance + spacing) with a post-hoc fix for Soprano–Alto parallels. Approximation 6 keeps the same greedy cost but switches to logarithmic duration mapping, which compresses the dynamic range of note lengths so very short events stay audible. Approximation 7 keeps the logarithmic duration and replaces the greedy cost with a lookahead-aware one — semitones, tritones, parallel fifths and octaves are penalised across consecutive steps, and contrary motion is rewarded. Approximation 8 is informed by a corpus analysis of Bach's Well-Tempered Clavier Book I: inner voices strongly prefer stepwise motion (M2/m2, as in ~70 % of WTC fugue intervals), harmonic thirds and sixths are favoured over fourths and fifths, large leaps are resolved in the opposite direction, contrary motion between outer voices is explicitly rewarded, and the lookahead extends two steps ahead. Approximation 9 adds WTC-inspired rhythmic post-processing to Approximation 8's voice leading: the 43 000-note corpus analysis showed that 72.5 % of consecutive note transitions maintain identical duration and that jumps larger than 2:1 never occur. The algorithm enforces both rules — adjacent figures are merged into runs of uniform motion, and any transition exceeding a 2:1 ratio is capped — producing the characteristic continuous-flow rhythm of Bach's preludes and fugues.",
      "Soprano + Alto share the major-groove duration; Tenor + Bass share the minor-groove duration — two rhythmically independent duets that overlap.",
    ],
    algo_link_label: "Read the full sonification page",
    algo_link_href: "https://danslab.xyz/outreach/sonification/",
  },
  es: {
    back: "← Web del laboratorio",
    eyebrow: "ADN → Música · Aproximación 5 a 7",
    title: "Sonifica una secuencia de ADN",
    lede:
      "Cada tetranucleótido se asigna a un acorde a cuatro voces (SATB). Soprano y Bajo provienen de la dinámica de los surcos mayor y menor; Alto y Tenor se generan para maximizar la consonancia armónica.",
    console_heading: "ADN → Música · consola",
    seq_label: "Secuencia",
    seq_placeholder:
      "Pega tu secuencia aquí (A, T, C, G) — máx. 200 bases\nEjemplo: GCAACGTGCTATGGAAGCGCAATAAGTACC",
    seq_hint: (count, max) =>
      `Solo se usan las letras A, T, C, G · mínimo 4 bases · ${count} / ${max}`,
    scale_label: "Tonalidad",
    scale_active: "Activa",
    tonal_label: "Tonal",
    chromatic_label: "Cromática (12 tonos, sin ajuste)",
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
      d_dbl_harm: "Re doble armónica (bizantina)",
      d_octatonic: "Re octatónica (T–S, disminuida)",
    },
    aprox_label: "Algoritmo",
    aprox_select_label: "Elegir",
    meter_label: "Compás",
    meter_free: "Libre",
    meter_44: "4/4",
    aprox_active: "Activo",
    aprox_full: (n) => `Aproximación ${n}`,
    aprox_descriptions: {
      5: "Duración lineal · coste armónico voraz · corrección posterior de paralelismos S–A",
      6: "Duración logarítmica · coste armónico voraz · corrección posterior de paralelismos S–A",
      7: "Duración logarítmica · coste con anticipación (penaliza semitonos, tritonos, paralelos)",
      8: "Duración logarítmica · inspirado en Bach/CBI: grado conjunto, 3ras y 6tas, resolución de saltos, anticipación a 2 pasos",
      9: "Duración logarítmica · normalización rítmica del CBI (homogeneización de grupos, transiciones máx. 2:1, agrupaciones binarias) · conducción de voces del CBI",
      10: "Duración logarítmica · conducción de voces CBI · inversión de roles: T lleva los datos del surco menor, B es la voz generada (fix)",
      11: "Duración logarítmica · S es una melodía en arco planificada (punto álgido al ~60 %, 2–4 saltos, reglas de cambio de sentido, intervalos del CBI) · conducción de voces CBI para A, T, B",
    },
    mix_label: "Mezcla de volumen",
    mix_voice: { s: "Soprano", a: "Alto", t: "Tenor", b: "Bajo" },
    mix_voice_origin: {
      s: "Surco mayor",
      a: "Fix",
      t: "Fix",
      b: "Surco menor",
    },
    mix_voice_origin_10: {
      s: "Surco mayor",
      a: "Fix",
      t: "Surco menor",
      b: "Fix",
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
    rewind: "⏮ Reiniciar",
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
      "La Soprano sigue el tono del surco mayor; el Bajo, el del surco menor. Alto y Tenor se eligen dentro de la escala activa maximizando la consonancia con el Bajo.",
      "Hay cinco variantes del algoritmo. La Aproximación 5 usa un mapeo lineal de duración y un coste armónico voraz (movimiento + disonancia + espaciado) con corrección posterior de paralelismos Soprano–Alto. La Aproximación 6 mantiene el mismo coste voraz pero cambia a un mapeo logarítmico de duración, que comprime el rango dinámico de los valores rítmicos para que los eventos muy cortos sigan siendo audibles. La Aproximación 7 conserva la duración logarítmica y reemplaza el coste voraz por uno con anticipación: penaliza semitonos, tritonos y quintas/octavas paralelas a través de pasos consecutivos, y premia el movimiento contrario. La Aproximación 8 se nutre del análisis de corpus del Clave Bien Temperado Libro I de Bach: las voces internas prefieren fuertemente el movimiento por grado conjunto (M2/m2, como en el ~70 % de los intervalos de las fugas del CBI), se favorecen las terceras y sextas armónicas sobre las cuartas y quintas, los saltos grandes se resuelven en dirección contraria, el movimiento contrario entre las voces exteriores se premia explícitamente, y la anticipación se extiende a dos pasos. La Aproximación 9 añade un post-procesado rítmico inspirado en el CBI a la conducción de voces de la Aproximación 8: el análisis de 43 000 notas mostró que el 72,5 % de las transiciones consecutivas mantienen la misma duración y que jamás aparecen saltos superiores a 2:1. El algoritmo impone ambas reglas — las figuras adyacentes se fusionan en grupos de movimiento uniforme y cualquier transición que supere la razón 2:1 se recorta — produciendo el flujo rítmico continuo característico de los preludios y fugas de Bach.",
      "Soprano + Alto comparten la duración del surco mayor; Tenor + Bajo comparten la del surco menor — dos dúos rítmicamente independientes que se superponen.",
    ],
    algo_link_label: "Más información en la página del laboratorio",
    algo_link_href: "https://danslab.xyz/es/outreach/sonification/",
  },
};
