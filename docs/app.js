'use strict';

// ============================================================
// CONSTANTS
// ============================================================
const NOTE_NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
const PPQ = 480;

// Chromatic sets as absolute pitch classes (C=0 … B=11)
// Scales that share the same set produce identical snapping results.
const SCALES = {
  d_minor:    [0,2,4,5,7,9,10],   // D E F G A Bb C
  g_minor:    [0,2,3,5,7,9,10],   // G A Bb C D E F
  c_minor:    [0,2,3,5,7,8,10],   // C D Eb F G Ab Bb
  a_minor:    [0,2,4,5,7,9,11],   // A B C D E F G  (= Do mayor)
  e_minor:    [0,2,4,6,7,9,11],   // E F# G A B C D (= Sol mayor)
  d_major:    [1,2,4,6,7,9,11],   // D E F# G A B C#
  a_major:    [1,2,4,6,8,9,11],   // A B C# D E F# G#
  d_phrygian: [0,1,3,5,7,8,10],   // D Eb F G A Bb C
  d_min_pent: [0,2,5,7,9],        // D F G A C
  d_maj_pent: [2,4,6,9,11],       // D E F# A B
};

// Voice registers: [lo, hi, center] in MIDI numbers
const S_REG = [62, 86, 69]; // Soprano D4–D6, center A4
const A_REG = [55, 72, 62]; // Alto    G3–C5, center D4
const T_REG = [48, 67, 57]; // Tenor   C3–G4, center A3
const B_REG = [38, 62, 50]; // Bass    D2–D4, center D3

// Consonances (interval mod 12): P1, m3, M3, P5, m6, M6
const CONSONANT = new Set([0, 3, 4, 7, 8, 9]);

// ============================================================
// CORE ALGORITHM — mirrors generar_midi_aprox7.pl
// ============================================================

function snapToScale(midi, chroma) {
  const pc   = midi % 12;
  const base = midi - pc;
  let bestC = chroma[0], bestDiff = 99;
  for (const c of chroma) {
    let diff = Math.abs(pc - c);
    if (diff > 6) diff = 12 - diff;
    if (diff < bestDiff) { bestDiff = diff; bestC = c; }
  }
  let n = base + bestC;
  if (pc - bestC >  6) n += 12;
  if (bestC - pc >  6) n -= 12;
  return n;
}

function forceRegister(midi, center, lo, hi) {
  const pc = midi % 12;
  let best = midi, bestDiff = 999;
  for (let oct = 0; oct <= 9; oct++) {
    const c = oct * 12 + pc;
    if (c < lo || c > hi) continue;
    const diff = Math.abs(c - center);
    if (diff < bestDiff) { bestDiff = diff; best = c; }
  }
  return best;
}

function applyVoiceLeading(notes, maxLeap, lo, hi) {
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

function isConsonant(a, b) { return CONSONANT.has((a - b + 144) % 12); }

function hasParallel(v1p, v2p, v1c, v2c) {
  if (v1p == null) return false;
  const pi = (v1p - v2p + 144) % 12;
  const ci = (v1c - v2c + 144) % 12;
  return (pi === 7 && ci === 7) || (pi === 0 && ci === 0);
}

function scaleNotesInRange(chroma, lo, hi) {
  const notes = [];
  for (let oct = 0; oct <= 9; oct++)
    for (const c of chroma) {
      const n = oct * 12 + c;
      if (n >= lo && n <= hi) notes.push(n);
    }
  return notes.sort((a, b) => a - b);
}

// R7: move soprano up one scale degree if S-B parallel 5th/8th
function checkParallelSB(sPrev, bPrev, s, b, sScale) {
  if (sPrev == null) return s;
  const pi = (sPrev - bPrev + 144) % 12;
  const ci = (s     - b     + 144) % 12;
  if ((pi === 7 && ci === 7) || (pi === 0 && ci === 0)) {
    const idx = sScale.indexOf(s);
    if (idx >= 0 && idx < sScale.length - 1) return sScale[idx + 1];
  }
  return s;
}

// R5 — Generate Alto with lookahead (aprox7 cost function)
function generateAlto(s, b, prevA, sPrev, bNext, aScale) {
  let best = null, bestScore = Infinity;
  for (const c of aScale) {
    if (c >= s) continue;
    const motion = Math.abs(c - prevA);
    let score = Math.min(motion, 6);                           // smoothness (cap 6)
    if (motion === 1)  score += 12;                            // semitone penalty
    if (motion === 6)  score += 5;                             // tritone penalty
    if (!isConsonant(c, b))  score += 15;                      // dissonance now
    if (bNext != null && !isConsonant(c, bNext))  score += 8;  // dissonance next (lookahead)
    if (s - c < 3)  score += 5;                                // too close to soprano
    if (hasParallel(sPrev, prevA, s, c))  score += 20;         // parallel S-A
    if (sPrev != null && s !== sPrev && motion > 0)
      if ((s > sPrev) === (c > prevA))  score += 3;            // parallel direction
    if (c === prevA)  score += 3;                              // repeated note
    score += Math.floor(Math.abs(c - A_REG[2]) / 4);          // range center pull
    if (score < bestScore) { bestScore = score; best = c; }
  }
  return best ?? prevA;
}

// R6 — Generate Tenor with lookahead (aprox7 cost function)
function generateTenor(s, b, a, prevT, sPrev, bPrev, bNext, tScale) {
  let best = null, bestScore = Infinity;
  for (const c of tScale) {
    if (c >= a || c <= b) continue;
    const motion = Math.abs(c - prevT);
    let score = Math.min(motion, 6);
    if (motion === 1)  score += 12;
    if (motion === 6)  score += 5;
    if (!isConsonant(c, b))  score += 15;
    if (bNext != null && !isConsonant(c, bNext))  score += 8;
    if (hasParallel(sPrev, prevT, s, c))  score += 20;        // parallel S-T
    if (hasParallel(bPrev, prevT, b, c))  score += 20;        // parallel B-T
    if (sPrev != null && s !== sPrev && motion > 0)
      if ((s > sPrev) === (c > prevT))  score += 3;
    if (c === prevT)  score += 3;
    score += Math.floor(Math.abs(c - T_REG[2]) / 4);
    if (score < bestScore) { bestScore = score; best = c; }
  }
  // Fallback if no valid position (unavoidable voice crossing)
  if (best == null) {
    const mid = Math.floor((a + b) / 2);
    best = tScale.reduce((acc, n) => Math.abs(n - mid) < Math.abs(acc - mid) ? n : acc, tScale[0]);
  }
  return best;
}

// ============================================================
// MAIN PIPELINE
// ============================================================
function processSequence(rawSeq, scaleKey, bpm, tables) {
  const chroma = SCALES[scaleKey];
  const sScale = scaleNotesInRange(chroma, ...S_REG);
  const aScale = scaleNotesInRange(chroma, ...A_REG);
  const tScale = scaleNotesInRange(chroma, ...T_REG);

  // Parse tetranucleotides (overlapping, step 1)
  const seq    = rawSeq.toUpperCase().replace(/[^ACGT]/g, '');
  const tetras = [];
  for (let i = 0; i + 4 <= seq.length; i++) tetras.push(seq.slice(i, i + 4));
  if (tetras.length === 0) throw new Error('Secuencia demasiado corta (mínimo 4 bases).');

  // R1–R3: Soprano and Bass raw notes + durations
  const sRaw = [], bRaw = [], sDurs = [], bDurs = [];
  for (const t of tetras) {
    const row = tables[t];
    if (!row) throw new Error(`Tetranucleótido desconocido: ${t}`);
    sRaw.push(forceRegister(snapToScale(row.mg_midi, chroma), S_REG[2], S_REG[0], S_REG[1]));
    bRaw.push(forceRegister(snapToScale(row.mn_midi, chroma), B_REG[2], B_REG[0], B_REG[1]));
    sDurs.push(row.mg_ticks);
    bDurs.push(row.mn_ticks);
  }
  let sNotes = applyVoiceLeading(sRaw, 7, S_REG[0], S_REG[1]);
  let bNotes = applyVoiceLeading(bRaw, 7, B_REG[0], B_REG[1]);

  // R7: Anti-parallel S-B
  for (let i = 1; i < sNotes.length; i++)
    sNotes[i] = checkParallelSB(sNotes[i-1], bNotes[i-1], sNotes[i], bNotes[i], sScale);

  // R5–R6: Alto and Tenor with lookahead
  const aNotes = [], tNotes = [];
  let prevA = 62, prevT = 52;
  for (let i = 0; i < tetras.length; i++) {
    const s     = sNotes[i], b = bNotes[i];
    const sPrev = i > 0 ? sNotes[i-1] : null;
    const bPrev = i > 0 ? bNotes[i-1] : null;
    const bNext = i < tetras.length - 1 ? bNotes[i+1] : null;
    const a = generateAlto(s, b, prevA, sPrev, bNext, aScale);
    const t = generateTenor(s, b, a, prevT, sPrev, bPrev, bNext, tScale);
    aNotes.push(a); tNotes.push(t);
    prevA = a; prevT = t;
  }

  return { tetras, sNotes, aNotes, tNotes, bNotes, sDurs, bDurs, seq, chroma };
}

// ============================================================
// MIDI GENERATION
// ============================================================
function vlq(n) {
  if (n < 128) return [n];
  const out = [];
  out.push(n & 0x7F); n >>= 7;
  while (n > 0) { out.push((n & 0x7F) | 0x80); n >>= 7; }
  return out.reverse();
}
const u16 = n => [(n >> 8) & 0xFF, n & 0xFF];
const u32 = n => [(n>>24)&0xFF, (n>>16)&0xFF, (n>>8)&0xFF, n&0xFF];
function strBytes(s) { return [...s].map(c => c.charCodeAt(0)); }
function chunk(type, data) { return [...strBytes(type), ...u32(data.length), ...data]; }

function buildTrack(notes, durs, ch, program, name) {
  const nb = strBytes(name);
  const bytes = [...vlq(0), 0xFF, 0x03, nb.length, ...nb,   // track name
                 ...vlq(0), 0xC0|ch, program];               // program change
  for (let i = 0; i < notes.length; i++) {
    const m = notes[i], d = durs[i];
    bytes.push(...vlq(0), 0x90|ch, m, 85);                  // note on  (vel 85)
    bytes.push(...vlq(d), 0x80|ch, m, 0);                   // note off
  }
  bytes.push(...vlq(0), 0xFF, 0x2F, 0x00);                  // end of track
  return bytes;
}

function buildMidi(result, bpm) {
  const tempoUs = Math.round(60_000_000 / bpm);
  const tempoTrack = [
    ...vlq(0), 0xFF, 0x03, 5, ...strBytes('Tempo'),
    ...vlq(0), 0xFF, 0x51, 0x03,
    (tempoUs>>16)&0xFF, (tempoUs>>8)&0xFF, tempoUs&0xFF,
    ...vlq(0), 0xFF, 0x2F, 0x00
  ];
  const tracks = [
    tempoTrack,
    buildTrack(result.sNotes, result.sDurs, 0,  0, 'Soprano'),
    buildTrack(result.aNotes, result.sDurs, 1,  0, 'Alto'),
    buildTrack(result.tNotes, result.bDurs, 2,  0, 'Tenor'),
    buildTrack(result.bNotes, result.bDurs, 3, 43, 'Bajo'),
  ];
  const header = [...strBytes('MThd'), ...u32(6), ...u16(1), ...u16(tracks.length), ...u16(PPQ)];
  const bytes = [...header, ...tracks.flatMap(t => chunk('MTrk', t))];
  return new Uint8Array(bytes);
}

// ============================================================
// PLAYBACK (Tone.js)
// ============================================================
let pianoSynth = null, bassSynth = null;

function initSynths() {
  pianoSynth = new Tone.PolySynth(Tone.Synth, {
    oscillator: { type: 'triangle4' },
    envelope:   { attack: 0.005, decay: 0.25, sustain: 0.45, release: 1.8 },
    volume: -12
  }).toDestination();

  bassSynth = new Tone.MonoSynth({
    oscillator:     { type: 'sawtooth' },
    envelope:       { attack: 0.01, decay: 0.1, sustain: 0.8, release: 0.6 },
    filterEnvelope: { attack: 0.001, decay: 0.15, sustain: 0.6, release: 0.3,
                      baseFrequency: 100, octaves: 1.5 },
    volume: -8
  }).toDestination();
}

const midiToHz = midi => 440 * Math.pow(2, (midi - 69) / 12);

function schedulePlayback(result, bpm) {
  Tone.Transport.cancel();
  Tone.Transport.stop();

  const secPerTick = 60 / (bpm * PPQ);

  // Precompute cumulative start times for each groove stream
  const sCumSec = [], bCumSec = [];
  let cumS = 0, cumB = 0;
  for (let i = 0; i < result.tetras.length; i++) {
    sCumSec.push(cumS * secPerTick); cumS += result.sDurs[i];
    bCumSec.push(cumB * secPerTick); cumB += result.bDurs[i];
  }

  // Soprano + Alto share major-groove timing
  [result.sNotes, result.aNotes].forEach((voice, vi) => {
    const vel = vi === 0 ? 0.75 : 0.45;
    voice.forEach((midi, i) => {
      const start = sCumSec[i], dur = result.sDurs[i] * secPerTick;
      const freq  = midiToHz(midi);
      Tone.Transport.schedule(t => pianoSynth.triggerAttackRelease(freq, dur, t, vel), start);
    });
  });

  // Tenor + Bass share minor-groove timing
  result.tNotes.forEach((midi, i) => {
    const start = bCumSec[i], dur = result.bDurs[i] * secPerTick;
    Tone.Transport.schedule(t => pianoSynth.triggerAttackRelease(midiToHz(midi), dur, t, 0.4), start);
  });
  result.bNotes.forEach((midi, i) => {
    const start = bCumSec[i], dur = result.bDurs[i] * secPerTick;
    Tone.Transport.schedule(t => bassSynth.triggerAttackRelease(midiToHz(midi), dur, t, 0.8), start);
  });
}

function stopPlayback() {
  Tone.Transport.stop();
  Tone.Transport.cancel();
  pianoSynth?.releaseAll();
}

// ============================================================
// UTILITIES
// ============================================================
const mn = midi => NOTE_NAMES[midi % 12] + (Math.floor(midi / 12) - 1);

function estimateDuration(sDurs, bDurs, bpm) {
  const totalS = sDurs.reduce((a, b) => a + b, 0);
  const totalB = bDurs.reduce((a, b) => a + b, 0);
  const ticks  = Math.max(totalS, totalB);
  const secs   = ticks / PPQ * 60 / bpm;
  const m = Math.floor(secs / 60), s = Math.floor(secs % 60);
  return `${m}:${String(s).padStart(2, '0')}`;
}

function buildSample(result) {
  const n = Math.min(8, result.tetras.length);
  let lines = ['Tetra   S     A     T     B'];
  for (let i = 0; i < n; i++) {
    lines.push(`${result.tetras[i]}    ${mn(result.sNotes[i]).padEnd(5)} ${mn(result.aNotes[i]).padEnd(5)} ${mn(result.tNotes[i]).padEnd(5)} ${mn(result.bNotes[i])}`);
  }
  return lines.join('\n');
}

function buildStats(result, bpm) {
  const dur = estimateDuration(result.sDurs, result.bDurs, bpm);
  const disAB = result.aNotes.filter((a,i) => !isConsonant(a, result.bNotes[i])).length;
  const semiA = result.aNotes.filter((a,i) => i>0 && Math.abs(a - result.aNotes[i-1])===1).length;
  return [
    { val: result.tetras.length, lbl: 'Tetranucleótidos' },
    { val: dur,   lbl: 'Duración estimada' },
    { val: `${result.seq.length} bp`, lbl: 'Bases procesadas' },
    { val: `${disAB}/${result.tetras.length}`, lbl: 'Disonancias A–B' },
    { val: semiA, lbl: 'Semitonos Alto' },
  ];
}

// ============================================================
// UI
// ============================================================
let tables = null;
let lastMidiBytes = null;

const $ = id => document.getElementById(id);

function setStatus(msg, cls = '') {
  const el = $('status');
  el.textContent = msg;
  el.className = cls;
}

async function init() {
  try {
    const resp = await fetch('tables.json');
    if (!resp.ok) throw new Error(`tables.json: HTTP ${resp.status}`);
    tables = await resp.json();
    setStatus('Listo. Pega tu secuencia y pulsa Generar.', 'ok');
    $('btn-generate').disabled = false;
    initSynths();
  } catch (e) {
    setStatus(`Error cargando datos: ${e.message}`, 'error');
  }
}

// Sequence counter
$('seq').addEventListener('input', () => {
  const cleaned = $('seq').value.toUpperCase().replace(/[^ACGT\s\n]/g, '');
  const bases   = cleaned.replace(/\s/g, '').length;
  $('base-count').textContent = Math.min(bases, 200);
});

// Generate
$('btn-generate').addEventListener('click', () => {
  const rawSeq   = $('seq').value;
  const scaleKey = $('scale').value;
  const bpm      = parseInt($('bpm').value, 10);

  if (!tables) { setStatus('Datos aún no cargados.', 'error'); return; }
  if (bpm < 30 || bpm > 240) { setStatus('Tempo fuera de rango (30–240 BPM).', 'error'); return; }

  try {
    setStatus('Generando…');
    const result = processSequence(rawSeq, scaleKey, bpm, tables);

    // Build MIDI
    lastMidiBytes = buildMidi(result, bpm);
    const blob = new Blob([lastMidiBytes], { type: 'audio/midi' });
    const url  = URL.createObjectURL(blob);
    const dl   = $('btn-download');
    dl.href     = url;
    dl.download = `dna-${result.seq.slice(0, 16)}.mid`;

    // Schedule playback (without starting)
    schedulePlayback(result, bpm);

    // Show player
    $('player').classList.add('visible');

    // Stats
    const stats = buildStats(result, bpm);
    $('stats').innerHTML = stats.map(s =>
      `<div class="stat-box"><div class="val">${s.val}</div><div class="lbl">${s.lbl}</div></div>`
    ).join('');

    // Sample
    $('sample').textContent = buildSample(result);

    setStatus(`Generado: ${result.tetras.length} notas · ${estimateDuration(result.sDurs, result.bDurs, bpm)} a ${bpm} BPM`, 'ok');
  } catch (e) {
    setStatus(`Error: ${e.message}`, 'error');
  }
});

// Play
$('btn-play').addEventListener('click', async () => {
  await Tone.start();  // resume AudioContext after user gesture
  Tone.Transport.start();
  $('btn-play').disabled  = true;
  $('btn-stop').disabled  = false;
});

// Stop
$('btn-stop').addEventListener('click', () => {
  stopPlayback();
  $('btn-play').disabled  = false;
  $('btn-stop').disabled  = true;
});

document.addEventListener('DOMContentLoaded', init);
