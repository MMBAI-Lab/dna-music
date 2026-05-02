"use client";

import * as Tone from "tone";
import { DEFAULT_MIX, PPQ, type ProcessResult, type VoiceMix } from "@/lib/dnaMusic";

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

// Base velocities tuned per voice — the user's mix scales these
// (mix value 0–100 → multiplier 0–1).
const BASE_VEL = { s: 0.75, a: 0.45, t: 0.4, b: 0.8 };

export function schedulePlayback(
  result: ProcessResult,
  bpm: number,
  mix: VoiceMix = DEFAULT_MIX,
  onEnd?: () => void,
) {
  initSynths();
  const transport = Tone.getTransport();
  // Order matters: stop first (resets time to 0), then cancel events at >=0,
  // then explicitly seek to 0 in case stop() didn't reset reliably.
  transport.stop();
  transport.cancel(0);
  transport.seconds = 0;

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

  const scale = { s: mix.s / 100, a: mix.a / 100, t: mix.t / 100, b: mix.b / 100 };

  // Soprano + Alto share major-groove timing
  if (scale.s > 0) {
    result.sNotes.forEach((midi, i) => {
      const start = sCumSec[i];
      const dur = result.sDurs[i] * secPerTick;
      const freq = midiToHz(midi);
      transport.schedule(
        (t) => pianoSynth!.triggerAttackRelease(freq, dur, t, BASE_VEL.s * scale.s),
        start,
      );
    });
  }
  if (scale.a > 0) {
    result.aNotes.forEach((midi, i) => {
      const start = sCumSec[i];
      const dur = result.sDurs[i] * secPerTick;
      const freq = midiToHz(midi);
      transport.schedule(
        (t) => pianoSynth!.triggerAttackRelease(freq, dur, t, BASE_VEL.a * scale.a),
        start,
      );
    });
  }

  // Tenor + Bass share minor-groove timing
  if (scale.t > 0) {
    result.tNotes.forEach((midi, i) => {
      const start = bCumSec[i];
      const dur = result.bDurs[i] * secPerTick;
      transport.schedule(
        (t) => pianoSynth!.triggerAttackRelease(midiToHz(midi), dur, t, BASE_VEL.t * scale.t),
        start,
      );
    });
  }
  if (scale.b > 0) {
    result.bNotes.forEach((midi, i) => {
      const start = bCumSec[i];
      const dur = result.bDurs[i] * secPerTick;
      transport.schedule(
        (t) => bassSynth!.triggerAttackRelease(midiToHz(midi), dur, t, BASE_VEL.b * scale.b),
        start,
      );
    });
  }

  // Fire onEnd shortly after the last note tail, then halt the transport so
  // a subsequent Play starts cleanly from 0.
  const totalSec = Math.max(cumS, cumB) * secPerTick + 1;
  transport.scheduleOnce(() => {
    transport.stop();
    onEnd?.();
  }, totalSec);
}

export async function startPlayback() {
  await Tone.start();
  Tone.getTransport().start();
}

export function stopPlayback() {
  const transport = Tone.getTransport();
  transport.stop();
  transport.cancel(0);
  transport.seconds = 0;
  pianoSynth?.releaseAll();
}
