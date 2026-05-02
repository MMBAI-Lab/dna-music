/**
 * DNA → Music engine — TypeScript port of generar_midi_aprox5p2.pl,
 * generar_midi_aprox6.pl and generar_midi_aprox7.pl.
 *
 * Three modes, selectable via aproxLevel:
 *   5  Linear duration normalisation. Greedy harmonic cost
 *      (motion + 15·dissonance + 5·spacing). R8 post-hoc fix for
 *      Soprano–Alto parallels.
 *   6  Logarithmic duration normalisation; same greedy cost as 5.
 *   7  Logarithmic duration. Lookahead-aware cost (penalises semitones,
 *      tritones, parallels, parallel direction; pulls toward register
 *      centre). R8 absorbed into the cost.
 *
 * In all three modes, Soprano and Bass come from the major / minor
 * groove dynamics data; Alto and Tenor are generated to maximise
 * harmonic consonance.
 */

// ============================================================
// CONSTANTS
// ============================================================
const NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"] as const;
export const PPQ = 480;

export const SCALES = {
  d_minor: [0, 2, 4, 5, 7, 9, 10],
  g_minor: [0, 2, 3, 5, 7, 9, 10],
  c_minor: [0, 2, 3, 5, 7, 8, 10],
  a_minor: [0, 2, 4, 5, 7, 9, 11],
  e_minor: [0, 2, 4, 6, 7, 9, 11],
  d_major: [1, 2, 4, 6, 7, 9, 11],
  a_major: [1, 2, 4, 6, 8, 9, 11],
  d_phrygian: [0, 1, 3, 5, 7, 8, 10],
  d_min_pent: [0, 2, 5, 7, 9],
  d_maj_pent: [2, 4, 6, 9, 11],
  // Double harmonic / Byzantine on D: D Eb F# G A Bb C# — two augmented
  // 2nds give the Arabic / sefardí flavour.
  d_dbl_harm: [1, 2, 3, 6, 7, 9, 10],
  // Octatonic W–H on D: D E F G G# A# B C# — 8 notes alternating
  // whole-half. Built on diminished 7th harmony, jazzy tension.
  d_octatonic: [1, 2, 4, 5, 7, 8, 10, 11],
} as const;

export type ScaleKey = keyof typeof SCALES;
export type AproxLevel = 5 | 6 | 7;
export const APROX_LEVELS: AproxLevel[] = [5, 6, 7];

// Chromatic 12-tone set — bypasses snap-to-scale so the dataset's raw
// pitches survive verbatim. Inner voices (A, T) are then chosen from the
// full chromatic in their register, not a 7-note diatonic subset.
export const CHROMATIC: readonly number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

// Voice registers: [lo, hi, center] in MIDI numbers
const S_REG: [number, number, number] = [62, 86, 69];
const A_REG: [number, number, number] = [55, 72, 62];
const T_REG: [number, number, number] = [48, 67, 57];
const B_REG: [number, number, number] = [38, 62, 50];

// Consonances (interval mod 12): P1, m3, M3, P5, m6, M6
const CONSONANT = new Set([0, 3, 4, 7, 8, 9]);

// ============================================================
// TYPES
// ============================================================
export type TableRow = {
  mg_midi: number;
  mg_ticks_lin: number;
  mg_ticks_log: number;
  mn_midi: number;
  mn_ticks_lin: number;
  mn_ticks_log: number;
};
export type Tables = Record<string, TableRow>;

/** Per-voice volume in 0–100. 0 mutes the voice (skipped from playback and MIDI). */
export type VoiceMix = { s: number; a: number; t: number; b: number };

export const DEFAULT_MIX: VoiceMix = { s: 100, a: 100, t: 100, b: 100 };

export interface ProcessResult {
  tetras: string[];
  sNotes: number[];
  aNotes: number[];
  tNotes: number[];
  bNotes: number[];
  sDurs: number[];
  bDurs: number[];
  seq: string;
  chroma: readonly number[];
  aproxLevel: AproxLevel;
}

// ============================================================
// SHARED HELPERS
// ============================================================
function snapToScale(midi: number, chroma: readonly number[]): number {
  const pc = midi % 12;
  const base = midi - pc;
  let bestC = chroma[0];
  let bestDiff = 99;
  for (const c of chroma) {
    let diff = Math.abs(pc - c);
    if (diff > 6) diff = 12 - diff;
    if (diff < bestDiff) {
      bestDiff = diff;
      bestC = c;
    }
  }
  let n = base + bestC;
  if (pc - bestC > 6) n += 12;
  if (bestC - pc > 6) n -= 12;
  return n;
}

function forceRegister(midi: number, center: number, lo: number, hi: number): number {
  const pc = midi % 12;
  let best = midi;
  let bestDiff = 999;
  for (let oct = 0; oct <= 9; oct++) {
    const c = oct * 12 + pc;
    if (c < lo || c > hi) continue;
    const diff = Math.abs(c - center);
    if (diff < bestDiff) {
      bestDiff = diff;
      best = c;
    }
  }
  return best;
}

function applyVoiceLeading(notes: number[], maxLeap: number, lo: number, hi: number): number[] {
  const out = [notes[0]];
  for (let i = 1; i < notes.length; i++) {
    let curr = notes[i];
    const prev = out[i - 1];
    if (Math.abs(curr - prev) > maxLeap) {
      const adj = curr > prev ? curr - 12 : curr + 12;
      if (adj >= lo && adj <= hi) curr = adj;
    }
    out.push(curr);
  }
  return out;
}

function isConsonant(a: number, b: number): boolean {
  return CONSONANT.has((a - b + 144) % 12);
}

function hasParallel(
  v1p: number | null,
  v2p: number | null,
  v1c: number,
  v2c: number,
): boolean {
  if (v1p == null || v2p == null) return false;
  const pi = (v1p - v2p + 144) % 12;
  const ci = (v1c - v2c + 144) % 12;
  return (pi === 7 && ci === 7) || (pi === 0 && ci === 0);
}

function scaleNotesInRange(chroma: readonly number[], lo: number, hi: number): number[] {
  const notes: number[] = [];
  for (let oct = 0; oct <= 9; oct++) {
    for (const c of chroma) {
      const n = oct * 12 + c;
      if (n >= lo && n <= hi) notes.push(n);
    }
  }
  return notes.sort((a, b) => a - b);
}

// R7: move soprano up one scale degree if S–B parallel 5th/8th
function checkParallelSB(
  sPrev: number | null,
  bPrev: number | null,
  s: number,
  b: number,
  sScale: number[],
): number {
  if (sPrev == null || bPrev == null) return s;
  const pi = (sPrev - bPrev + 144) % 12;
  const ci = (s - b + 144) % 12;
  if ((pi === 7 && ci === 7) || (pi === 0 && ci === 0)) {
    const idx = sScale.indexOf(s);
    if (idx >= 0 && idx < sScale.length - 1) return sScale[idx + 1];
  }
  return s;
}

// R8 (aprox5/6 only): move alto down one scale degree if S–A parallel.
// Walk up the scale until we find the slot above the current alto, then
// step down — mirrors the Perl loop that finds A_SCALE[i] == a and
// returns A_SCALE[i-1] (provided it stays below soprano).
function checkParallelSA(
  sPrev: number | null,
  aPrev: number | null,
  s: number,
  a: number,
  aScale: number[],
): number {
  if (sPrev == null || aPrev == null) return a;
  const pi = (sPrev - aPrev + 144) % 12;
  const ci = (s - a + 144) % 12;
  if ((pi === 7 && ci === 7) || (pi === 0 && ci === 0)) {
    for (let i = 1; i < aScale.length; i++) {
      if (aScale[i] === a && aScale[i - 1] < s) return aScale[i - 1];
    }
  }
  return a;
}

// ============================================================
// COST VARIANTS — Alto
// ============================================================

// aprox5 / aprox6: greedy, no lookahead
function generateAltoSimple(
  s: number,
  b: number,
  prevA: number,
  aScale: number[],
): number {
  let best: number | null = null;
  let bestScore = Infinity;
  for (const c of aScale) {
    if (c >= s) continue;
    let score = Math.abs(c - prevA);
    if (!isConsonant(c, b)) score += 15;
    if (s - c < 3) score += 5;
    if (score < bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return best ?? 62;
}

// aprox7: lookahead-aware with R8 absorbed
function generateAltoLookahead(
  s: number,
  b: number,
  prevA: number,
  sPrev: number | null,
  bNext: number | null,
  aScale: number[],
): number {
  let best: number | null = null;
  let bestScore = Infinity;
  for (const c of aScale) {
    if (c >= s) continue;
    const motion = Math.abs(c - prevA);
    let score = Math.min(motion, 6);
    if (motion === 1) score += 12;
    if (motion === 6) score += 5;
    if (!isConsonant(c, b)) score += 15;
    if (bNext != null && !isConsonant(c, bNext)) score += 8;
    if (s - c < 3) score += 5;
    if (hasParallel(sPrev, prevA, s, c)) score += 20;
    if (sPrev != null && s !== sPrev && motion > 0) {
      if (s > sPrev === c > prevA) score += 3;
    }
    if (c === prevA) score += 3;
    score += Math.floor(Math.abs(c - A_REG[2]) / 4);
    if (score < bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return best ?? prevA;
}

// ============================================================
// COST VARIANTS — Tenor
// ============================================================

function generateTenorSimple(
  b: number,
  a: number,
  prevT: number,
  tScale: number[],
): number {
  let best: number | null = null;
  let bestScore = Infinity;
  for (const c of tScale) {
    if (c >= a || c <= b) continue;
    let score = Math.abs(c - prevT);
    if (!isConsonant(c, b)) score += 15;
    if (score < bestScore) {
      bestScore = score;
      best = c;
    }
  }
  if (best == null) {
    const mid = Math.floor((a + b) / 2);
    best = tScale.reduce(
      (acc, n) => (Math.abs(n - mid) < Math.abs(acc - mid) ? n : acc),
      tScale[0],
    );
  }
  return best;
}

function generateTenorLookahead(
  s: number,
  b: number,
  a: number,
  prevT: number,
  sPrev: number | null,
  bPrev: number | null,
  bNext: number | null,
  tScale: number[],
): number {
  let best: number | null = null;
  let bestScore = Infinity;
  for (const c of tScale) {
    if (c >= a || c <= b) continue;
    const motion = Math.abs(c - prevT);
    let score = Math.min(motion, 6);
    if (motion === 1) score += 12;
    if (motion === 6) score += 5;
    if (!isConsonant(c, b)) score += 15;
    if (bNext != null && !isConsonant(c, bNext)) score += 8;
    if (hasParallel(sPrev, prevT, s, c)) score += 20;
    if (hasParallel(bPrev, prevT, b, c)) score += 20;
    if (sPrev != null && s !== sPrev && motion > 0) {
      if (s > sPrev === c > prevT) score += 3;
    }
    if (c === prevT) score += 3;
    score += Math.floor(Math.abs(c - T_REG[2]) / 4);
    if (score < bestScore) {
      bestScore = score;
      best = c;
    }
  }
  if (best == null) {
    const mid = Math.floor((a + b) / 2);
    best = tScale.reduce(
      (acc, n) => (Math.abs(n - mid) < Math.abs(acc - mid) ? n : acc),
      tScale[0],
    );
  }
  return best;
}

// ============================================================
// MAIN PIPELINE
// ============================================================
export function processSequence(
  rawSeq: string,
  scaleKey: ScaleKey,
  aproxLevel: AproxLevel,
  tables: Tables,
  tonalMode: boolean = true,
): ProcessResult {
  const chroma = tonalMode ? SCALES[scaleKey] : CHROMATIC;
  const sScale = scaleNotesInRange(chroma, S_REG[0], S_REG[1]);
  const aScale = scaleNotesInRange(chroma, A_REG[0], A_REG[1]);
  const tScale = scaleNotesInRange(chroma, T_REG[0], T_REG[1]);

  const seq = rawSeq.toUpperCase().replace(/[^ACGT]/g, "");
  const tetras: string[] = [];
  for (let i = 0; i + 4 <= seq.length; i++) tetras.push(seq.slice(i, i + 4));
  if (tetras.length === 0) {
    throw new Error("Sequence too short (need at least 4 bases).");
  }

  // aprox5 uses linear ticks; aprox6/7 use logarithmic
  const useLinearTicks = aproxLevel === 5;

  const sRaw: number[] = [];
  const bRaw: number[] = [];
  const sDurs: number[] = [];
  const bDurs: number[] = [];
  for (const t of tetras) {
    const row = tables[t];
    if (!row) throw new Error(`Unknown tetranucleotide: ${t}`);
    sRaw.push(forceRegister(snapToScale(row.mg_midi, chroma), S_REG[2], S_REG[0], S_REG[1]));
    bRaw.push(forceRegister(snapToScale(row.mn_midi, chroma), B_REG[2], B_REG[0], B_REG[1]));
    sDurs.push(useLinearTicks ? row.mg_ticks_lin : row.mg_ticks_log);
    bDurs.push(useLinearTicks ? row.mn_ticks_lin : row.mn_ticks_log);
  }
  const sNotes = applyVoiceLeading(sRaw, 7, S_REG[0], S_REG[1]);
  const bNotes = applyVoiceLeading(bRaw, 7, B_REG[0], B_REG[1]);

  // R7: anti-parallel S–B
  for (let i = 1; i < sNotes.length; i++) {
    sNotes[i] = checkParallelSB(sNotes[i - 1], bNotes[i - 1], sNotes[i], bNotes[i], sScale);
  }

  const aNotes: number[] = [];
  const tNotes: number[] = [];
  let prevA = 62;
  let prevT = 52;

  if (aproxLevel === 7) {
    // Lookahead path
    for (let i = 0; i < tetras.length; i++) {
      const s = sNotes[i];
      const b = bNotes[i];
      const sPrev = i > 0 ? sNotes[i - 1] : null;
      const bPrev = i > 0 ? bNotes[i - 1] : null;
      const bNext = i < tetras.length - 1 ? bNotes[i + 1] : null;
      const a = generateAltoLookahead(s, b, prevA, sPrev, bNext, aScale);
      const t = generateTenorLookahead(s, b, a, prevT, sPrev, bPrev, bNext, tScale);
      aNotes.push(a);
      tNotes.push(t);
      prevA = a;
      prevT = t;
    }
  } else {
    // aprox5 / aprox6: greedy + R8 post-hoc
    for (let i = 0; i < tetras.length; i++) {
      const s = sNotes[i];
      const b = bNotes[i];
      let a = generateAltoSimple(s, b, prevA, aScale);
      const sPrevR8 = i > 0 ? sNotes[i - 1] : null;
      const aPrevR8 = i > 0 ? aNotes[i - 1] : null;
      a = checkParallelSA(sPrevR8, aPrevR8, s, a, aScale);
      const t = generateTenorSimple(b, a, prevT, tScale);
      aNotes.push(a);
      tNotes.push(t);
      prevA = a;
      prevT = t;
    }
  }

  return { tetras, sNotes, aNotes, tNotes, bNotes, sDurs, bDurs, seq, chroma, aproxLevel };
}

// ============================================================
// MIDI GENERATION
// ============================================================
function vlq(n: number): number[] {
  if (n < 128) return [n];
  const out: number[] = [];
  out.push(n & 0x7f);
  n >>= 7;
  while (n > 0) {
    out.push((n & 0x7f) | 0x80);
    n >>= 7;
  }
  return out.reverse();
}
const u16 = (n: number) => [(n >> 8) & 0xff, n & 0xff];
const u32 = (n: number) => [(n >> 24) & 0xff, (n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff];
const strBytes = (s: string) => [...s].map((c) => c.charCodeAt(0));
const chunk = (type: string, data: number[]) => [...strBytes(type), ...u32(data.length), ...data];

function buildTrack(
  notes: number[],
  durs: number[],
  ch: number,
  program: number,
  name: string,
  velocity: number,
): number[] {
  const nb = strBytes(name);
  const bytes: number[] = [
    ...vlq(0),
    0xff,
    0x03,
    nb.length,
    ...nb,
    ...vlq(0),
    0xc0 | ch,
    program,
  ];
  for (let i = 0; i < notes.length; i++) {
    const m = notes[i];
    const d = durs[i];
    bytes.push(...vlq(0), 0x90 | ch, m, velocity);
    bytes.push(...vlq(d), 0x80 | ch, m, 0);
  }
  bytes.push(...vlq(0), 0xff, 0x2f, 0x00);
  return bytes;
}

const BASE_VELOCITY = 85;

export function buildMidi(
  result: ProcessResult,
  bpm: number,
  mix: VoiceMix = DEFAULT_MIX,
): Uint8Array {
  const tempoUs = Math.round(60_000_000 / bpm);
  const tempoTrack: number[] = [
    ...vlq(0),
    0xff,
    0x03,
    5,
    ...strBytes("Tempo"),
    ...vlq(0),
    0xff,
    0x51,
    0x03,
    (tempoUs >> 16) & 0xff,
    (tempoUs >> 8) & 0xff,
    tempoUs & 0xff,
    ...vlq(0),
    0xff,
    0x2f,
    0x00,
  ];

  const vel = (m: number) => Math.max(1, Math.round((BASE_VELOCITY * m) / 100));

  const tracks: number[][] = [tempoTrack];
  if (mix.s > 0) tracks.push(buildTrack(result.sNotes, result.sDurs, 0, 0, "Soprano", vel(mix.s)));
  if (mix.a > 0) tracks.push(buildTrack(result.aNotes, result.sDurs, 1, 0, "Alto", vel(mix.a)));
  if (mix.t > 0) tracks.push(buildTrack(result.tNotes, result.bDurs, 2, 0, "Tenor", vel(mix.t)));
  if (mix.b > 0) tracks.push(buildTrack(result.bNotes, result.bDurs, 3, 43, "Bass", vel(mix.b)));

  const header = [...strBytes("MThd"), ...u32(6), ...u16(1), ...u16(tracks.length), ...u16(PPQ)];
  const bytes = [...header, ...tracks.flatMap((t) => chunk("MTrk", t))];
  return new Uint8Array(bytes);
}

// ============================================================
// UTILITIES
// ============================================================
export const midiName = (midi: number) =>
  NOTE_NAMES[midi % 12] + (Math.floor(midi / 12) - 1);

export function estimateDuration(sDurs: number[], bDurs: number[], bpm: number): string {
  const totalS = sDurs.reduce((a, b) => a + b, 0);
  const totalB = bDurs.reduce((a, b) => a + b, 0);
  const ticks = Math.max(totalS, totalB);
  const secs = ((ticks / PPQ) * 60) / bpm;
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60);
  return `${m}:${String(s).padStart(2, "0")}`;
}

export function countDissonances(result: ProcessResult): { ab: number; tb: number } {
  let ab = 0;
  let tb = 0;
  for (let i = 0; i < result.aNotes.length; i++) {
    if (!isConsonant(result.aNotes[i], result.bNotes[i])) ab++;
    if (!isConsonant(result.tNotes[i], result.bNotes[i])) tb++;
  }
  return { ab, tb };
}

export function countAltoSemitones(result: ProcessResult): number {
  let n = 0;
  for (let i = 1; i < result.aNotes.length; i++) {
    if (Math.abs(result.aNotes[i] - result.aNotes[i - 1]) === 1) n++;
  }
  return n;
}
