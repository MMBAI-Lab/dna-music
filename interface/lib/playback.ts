"use client";

import * as Tone from "tone";
import { PPQ, type ProcessResult } from "@/lib/dnaMusic";

let pianoSynth: Tone.PolySynth | null = null;
let bassSynth: Tone.MonoSynth | null = null;

function initSynths() {
  if (pianoSynth && bassSynth) return;
  pianoSynth = new Tone.PolySynth(Tone.Synth, {
    oscillator: { type: "triangle4" },
    envelope: { attack: 0.005, decay: 0.25, sustain: 0.45, release: 1.8 },
    volume: -12,
  }).toDestination();

  bassSynth = new Tone.MonoSynth({
    oscillator: { type: "sawtooth" },
    envelope: { attack: 0.01, decay: 0.1, sustain: 0.8, release: 0.6 },
    filterEnvelope: {
      attack: 0.001,
      decay: 0.15,
      sustain: 0.6,
      release: 0.3,
      baseFrequency: 100,
      octaves: 1.5,
    },
    volume: -8,
  }).toDestination();
}

const midiToHz = (midi: number) => 440 * Math.pow(2, (midi - 69) / 12);

export function schedulePlayback(result: ProcessResult, bpm: number) {
  initSynths();
  Tone.Transport.cancel();
  Tone.Transport.stop();

  const secPerTick = 60 / (bpm * PPQ);

  const sCumSec: number[] = [];
  const bCumSec: number[] = [];
  let cumS = 0;
  let cumB = 0;
  for (let i = 0; i < result.tetras.length; i++) {
    sCumSec.push(cumS * secPerTick);
    cumS += result.sDurs[i];
    bCumSec.push(cumB * secPerTick);
    cumB += result.bDurs[i];
  }

  // Soprano + Alto share major-groove timing
  [result.sNotes, result.aNotes].forEach((voice, vi) => {
    const vel = vi === 0 ? 0.75 : 0.45;
    voice.forEach((midi, i) => {
      const start = sCumSec[i];
      const dur = result.sDurs[i] * secPerTick;
      const freq = midiToHz(midi);
      Tone.Transport.schedule((t) => pianoSynth!.triggerAttackRelease(freq, dur, t, vel), start);
    });
  });

  // Tenor + Bass share minor-groove timing
  result.tNotes.forEach((midi, i) => {
    const start = bCumSec[i];
    const dur = result.bDurs[i] * secPerTick;
    Tone.Transport.schedule(
      (t) => pianoSynth!.triggerAttackRelease(midiToHz(midi), dur, t, 0.4),
      start,
    );
  });
  result.bNotes.forEach((midi, i) => {
    const start = bCumSec[i];
    const dur = result.bDurs[i] * secPerTick;
    Tone.Transport.schedule(
      (t) => bassSynth!.triggerAttackRelease(midiToHz(midi), dur, t, 0.8),
      start,
    );
  });
}

export async function startPlayback() {
  await Tone.start();
  Tone.Transport.start();
}

export function stopPlayback() {
  Tone.Transport.stop();
  Tone.Transport.cancel();
  pianoSynth?.releaseAll();
}
