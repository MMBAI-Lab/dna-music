"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import FadeIn from "@/components/FadeIn";
import SonifBackground from "@/components/SonifBackground";
import Knob from "@/components/Knob";
import ToggleSwitch from "@/components/ToggleSwitch";
import RockerSwitch from "@/components/RockerSwitch";
import Fader from "@/components/Fader";
import { asset } from "@/lib/asset";
import type { Lang } from "@/lib/i18n";
import { PLAYER, SCALE_ABBREV } from "@/data/content/player";
import {
  APROX_LEVELS,
  DEFAULT_MIX,
  buildMidi,
  countAltoSemitones,
  countDissonances,
  estimateDuration,
  midiName,
  processSequence,
  type AproxLevel,
  type ProcessResult,
  type ScaleKey,
  type Tables,
  type VoiceMix,
} from "@/lib/dnaMusic";
import { schedulePlayback, startPlayback, stopPlayback } from "@/lib/playback";

const MAX_BASES = 200;

type Status =
  | { kind: "loading" }
  | { kind: "ready" }
  | { kind: "ok"; msg: string }
  | { kind: "error"; msg: string };

export default function PlayerPage({ lang }: { lang: Lang }) {
  const c = PLAYER[lang];

  const [tables, setTables] = useState<Tables | null>(null);
  const [status, setStatus] = useState<Status>({ kind: "loading" });
  const [seq, setSeq] = useState("");
  const [scaleKey, setScaleKey] = useState<ScaleKey>("d_minor");
  const [tonalMode, setTonalMode] = useState(true);
  const [aproxLevel, setAproxLevel] = useState<AproxLevel>(7);
  const [mix, setMix] = useState<VoiceMix>(DEFAULT_MIX);
  const [bpm, setBpm] = useState(72);
  const [result, setResult] = useState<ProcessResult | null>(null);
  const [midiUrl, setMidiUrl] = useState<string | null>(null);
  const [playing, setPlaying] = useState(false);

  const downloadName = useMemo(() => {
    if (!result) return "dna-music.mid";
    return `dna-${result.seq.slice(0, 16) || "sequence"}.mid`;
  }, [result]);

  // Load tables.json once on mount.
  useEffect(() => {
    let cancelled = false;
    fetch(asset("/tables.json"))
      .then((r) => {
        if (!r.ok) throw new Error(`tables.json: HTTP ${r.status}`);
        return r.json();
      })
      .then((j: Tables) => {
        if (cancelled) return;
        setTables(j);
        setStatus({ kind: "ready" });
      })
      .catch((e: Error) => {
        if (cancelled) return;
        setStatus({ kind: "error", msg: e.message });
      });
    return () => {
      cancelled = true;
    };
  }, []);

  // Revoke previous blob URL when a new one is created.
  const lastUrlRef = useRef<string | null>(null);
  useEffect(() => {
    return () => {
      if (lastUrlRef.current) URL.revokeObjectURL(lastUrlRef.current);
    };
  }, []);

  // Cleanup playback on unmount.
  useEffect(() => {
    return () => {
      stopPlayback();
    };
  }, []);

  const cleaned = seq.toUpperCase().replace(/[^ACGT]/g, "");
  const baseCount = Math.min(cleaned.length, MAX_BASES);

  function onGenerate() {
    if (!tables) {
      setStatus({ kind: "error", msg: "Data not loaded yet." });
      return;
    }
    if (bpm < 30 || bpm > 240) {
      setStatus({ kind: "error", msg: "Tempo out of range (30–240 BPM)." });
      return;
    }
    try {
      stopPlayback();
      setPlaying(false);
      const r = processSequence(seq, scaleKey, aproxLevel, tables, tonalMode);
      const bytes = buildMidi(r, bpm, mix);
      const blob = new Blob([new Uint8Array(bytes)], { type: "audio/midi" });
      const url = URL.createObjectURL(blob);
      if (lastUrlRef.current) URL.revokeObjectURL(lastUrlRef.current);
      lastUrlRef.current = url;
      setMidiUrl(url);
      setResult(r);
      schedulePlayback(r, bpm, mix, () => setPlaying(false));
      setStatus({
        kind: "ok",
        msg: c.status_done(r.tetras.length, estimateDuration(r.sDurs, r.bDurs, bpm), bpm),
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setStatus({ kind: "error", msg: c.status_error(msg) });
    }
  }

  async function onPlay() {
    await startPlayback();
    setPlaying(true);
  }

  function onStop() {
    stopPlayback();
    setPlaying(false);
  }

  async function onRewind() {
    if (!result) return;
    stopPlayback();
    schedulePlayback(result, bpm, mix, () => setPlaying(false));
    await startPlayback();
    setPlaying(true);
  }

  return (
    <>
      <SonifBackground />
      <div className="relative z-10 mx-auto max-w-5xl px-6 py-24">
        <FadeIn>
          <a
            href={c.algo_link_href}
            target="_blank"
            rel="noreferrer"
            className="text-xs font-semibold uppercase tracking-[0.3em] text-subtle hover:text-accent"
          >
            {c.back}
          </a>
          <h1 className="mt-6 font-serif text-4xl font-semibold tracking-tight text-ink md:text-5xl">
            {c.title}
          </h1>
          <p className="mt-3 text-sm font-medium uppercase tracking-[0.25em] text-accent">
            {c.eyebrow}
          </p>
        </FadeIn>

        <FadeIn delay={0.05}>
          <p className="mt-10 max-w-prose text-lg leading-relaxed text-muted">
            {c.lede}
          </p>
        </FadeIn>

        <FadeIn>
          <section className="console-panel mt-16 p-5 md:p-8">
            {/* Faceplate header — title strip with corner screws */}
            <div className="console-screws relative flex items-baseline border-b border-zinc-800 pb-4">
              <h2 className="font-serif text-base font-semibold uppercase tracking-[0.18em] text-zinc-100 md:text-lg">
                {c.console_heading}
              </h2>
            </div>

            {/* Sequence input */}
            <div className="mt-6">
              <label
                htmlFor="seq"
                className="block text-[0.65rem] font-bold uppercase tracking-[0.3em] text-zinc-300"
              >
                {c.seq_label}
              </label>
              <textarea
                id="seq"
                spellCheck={false}
                value={seq}
                onChange={(e) => setSeq(e.target.value)}
                placeholder={c.seq_placeholder}
                className="mt-2 block h-24 w-full resize-y rounded-sm border border-zinc-800 bg-black/70 px-3 py-2 font-mono text-sm tracking-[0.15em] text-zinc-100 shadow-[inset_0_2px_4px_rgba(0,0,0,0.6)] outline-none transition focus:border-accent"
              />
              <p className="mt-2 font-mono text-[0.65rem] uppercase tracking-widest text-zinc-500">
                {c.seq_hint(baseCount, MAX_BASES)}
              </p>
            </div>

            {/* Key bank + Tempo knob */}
            <div className="mt-8 flex flex-col gap-8 md:flex-row md:items-start md:justify-between md:gap-10">
              <div className="flex-1">
                <div className="flex items-center justify-between">
                  <p
                    id="key-bank-label"
                    className="text-[0.65rem] font-bold uppercase tracking-[0.3em] text-zinc-300"
                  >
                    {c.scale_label}
                  </p>
                  <button
                    type="button"
                    role="switch"
                    aria-checked={tonalMode}
                    onClick={() => setTonalMode((v) => !v)}
                    className="flex select-none items-center gap-2 rounded px-1 focus:outline-none focus-visible:ring-2 focus-visible:ring-accent"
                  >
                    <span
                      aria-hidden
                      className="block h-2 w-2 rounded-full transition-shadow"
                      style={{
                        background: tonalMode
                          ? "rgb(var(--accent))"
                          : "rgba(80,80,80,0.45)",
                        boxShadow: tonalMode
                          ? "0 0 8px 1px rgba(var(--accent) / 0.7), inset 0 0 1px rgba(255,255,255,0.5)"
                          : "inset 0 0 2px rgba(0,0,0,0.6)",
                      }}
                    />
                    <span className="font-mono text-[0.6rem] font-bold uppercase tracking-[0.2em] text-zinc-300">
                      {c.tonal_label}
                    </span>
                    <span
                      className="font-mono text-[0.55rem] font-bold uppercase tracking-[0.2em] tabular-nums"
                      style={{
                        color: tonalMode
                          ? "rgb(var(--accent))"
                          : "rgba(170,170,170,0.55)",
                      }}
                    >
                      {tonalMode ? "ON" : "OFF"}
                    </span>
                  </button>
                </div>
                <div
                  role="radiogroup"
                  aria-labelledby="key-bank-label"
                  aria-disabled={!tonalMode}
                  className={`mt-3 grid grid-cols-6 gap-x-2 gap-y-3 rounded-sm border border-zinc-900 bg-black/40 p-3 shadow-[inset_0_2px_4px_rgba(0,0,0,0.6)] sm:gap-x-3 ${
                    tonalMode ? "" : "pointer-events-none opacity-40"
                  }`}
                >
                  {(Object.keys(SCALE_ABBREV) as ScaleKey[]).map((k) => (
                    <ToggleSwitch
                      key={k}
                      checked={tonalMode && scaleKey === k}
                      label={SCALE_ABBREV[k]}
                      fullName={c.scales[k]}
                      onSelect={() => setScaleKey(k)}
                    />
                  ))}
                </div>
                <p className="mt-3 font-mono text-[0.7rem] uppercase tracking-widest text-zinc-400">
                  <span className="text-zinc-500">{c.scale_active}:</span>{" "}
                  <span className="text-accent">
                    {tonalMode ? c.scales[scaleKey] : c.chromatic_label}
                  </span>
                </p>
              </div>

              <div className="flex flex-col items-center md:pt-1">
                <p className="mb-3 text-[0.65rem] font-bold uppercase tracking-[0.3em] text-zinc-300">
                  {c.mix_label}
                </p>
                <div className="flex items-end gap-3 rounded-sm border border-zinc-900 bg-black/40 p-3 shadow-[inset_0_2px_4px_rgba(0,0,0,0.6)]">
                  <Fader
                    label={c.mix_voice.s}
                    subLabel={c.mix_voice_origin.s}
                    value={mix.s}
                    onChange={(v) => setMix((m) => ({ ...m, s: v }))}
                  />
                  <Fader
                    label={c.mix_voice.a}
                    subLabel={c.mix_voice_origin.a}
                    value={mix.a}
                    onChange={(v) => setMix((m) => ({ ...m, a: v }))}
                  />
                  <Fader
                    label={c.mix_voice.t}
                    subLabel={c.mix_voice_origin.t}
                    value={mix.t}
                    onChange={(v) => setMix((m) => ({ ...m, t: v }))}
                  />
                  <Fader
                    label={c.mix_voice.b}
                    subLabel={c.mix_voice_origin.b}
                    value={mix.b}
                    onChange={(v) => setMix((m) => ({ ...m, b: v }))}
                  />
                </div>
              </div>
            </div>

            {/* Algorithm rocker + LCD readout, and Tempo knob */}
            <div className="mt-8 flex flex-col gap-8 md:flex-row md:items-start md:justify-between md:gap-10">
              <div className="flex-1">
                <p
                  id="aprox-bank-label"
                  className="text-[0.65rem] font-bold uppercase tracking-[0.3em] text-zinc-300"
                >
                  {c.aprox_label}
                </p>
                <div className="mt-3 flex items-stretch gap-4 rounded-sm border border-zinc-900 bg-black/40 p-4 shadow-[inset_0_2px_4px_rgba(0,0,0,0.6)]">
                  <RockerSwitch
                    value={aproxLevel}
                    options={APROX_LEVELS}
                    topLabel={c.aprox_select_label}
                    ariaLabel={c.aprox_label}
                    onChange={setAproxLevel}
                  />
                  {/* LCD-style readout */}
                  <div
                    className="relative flex flex-1 flex-col justify-center rounded-sm border border-black/80 px-4 py-3"
                    style={{
                      background:
                        "linear-gradient(to bottom, #0b0b0b 0%, #050505 50%, #0b0b0b 100%)",
                      boxShadow:
                        "inset 0 2px 4px rgba(0,0,0,0.85), inset 0 -1px 1px rgba(255,255,255,0.04)",
                    }}
                  >
                    <span className="font-mono text-[0.55rem] uppercase tracking-[0.35em] text-zinc-500">
                      {c.aprox_active}
                    </span>
                    <span className="mt-1 font-mono text-2xl font-bold uppercase tracking-[0.12em] text-accent">
                      {c.aprox_full(aproxLevel)}
                    </span>
                    <span className="mt-2 font-mono text-[0.7rem] leading-relaxed text-zinc-300">
                      {c.aprox_descriptions[aproxLevel]}
                    </span>
                  </div>
                </div>
              </div>

              <div className="flex flex-col items-center md:pt-4">
                <Knob
                  value={bpm}
                  min={30}
                  max={240}
                  step={1}
                  size={104}
                  label={c.bpm_label}
                  unit={c.bpm_unit}
                  ariaLabel={c.bpm_label}
                  onChange={setBpm}
                />
              </div>
            </div>

            {/* Generate push-button + status readout */}
            <div className="mt-8 flex flex-col items-stretch gap-3 md:flex-row md:items-center">
              <button
                type="button"
                onClick={onGenerate}
                disabled={status.kind === "loading"}
                className="console-button"
              >
                <span className="console-button-led" aria-hidden />
                <span>{c.generate}</span>
              </button>
              <p
                className={`flex-1 rounded-sm border border-zinc-800 bg-black/70 px-3 py-2 font-mono text-[0.7rem] uppercase tracking-widest shadow-[inset_0_2px_4px_rgba(0,0,0,0.6)] ${
                  status.kind === "error"
                    ? "text-accent"
                    : status.kind === "ok"
                      ? "text-zinc-100"
                      : "text-zinc-500"
                }`}
              >
                {status.kind === "loading" && c.status_loading}
                {status.kind === "ready" && c.status_ready}
                {(status.kind === "ok" || status.kind === "error") && status.msg}
              </p>
            </div>
          </section>
        </FadeIn>

        {result && midiUrl && (
          <FadeIn>
            <section className="mt-12 rounded-lg border border-border bg-surface/80 p-6 backdrop-blur-sm md:p-8">
              <h2 className="font-serif text-2xl font-semibold tracking-tight text-ink">
                {c.player_heading}
              </h2>

              <div className="mt-5 flex flex-wrap gap-3">
                <button
                  type="button"
                  onClick={onPlay}
                  disabled={playing}
                  className="rounded-md bg-accent px-4 py-2 text-sm font-semibold text-white transition hover:bg-accent-hover disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {c.play}
                </button>
                <button
                  type="button"
                  onClick={onRewind}
                  className="rounded-md border border-border bg-elevated px-4 py-2 text-sm font-semibold text-ink transition hover:border-accent hover:text-accent"
                >
                  {c.rewind}
                </button>
                <button
                  type="button"
                  onClick={onStop}
                  disabled={!playing}
                  className="rounded-md border border-border bg-elevated px-4 py-2 text-sm font-semibold text-ink transition hover:border-accent hover:text-accent disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {c.stop}
                </button>
                <a
                  href={midiUrl}
                  download={downloadName}
                  className="rounded-md border border-border bg-elevated px-4 py-2 text-sm font-semibold text-ink transition hover:border-accent hover:text-accent"
                >
                  {c.download}
                </a>
              </div>

              <Stats result={result} bpm={bpm} c={c} />

              <h3 className="mt-8 text-xs font-semibold uppercase tracking-[0.2em] text-muted">
                {c.sample_heading}
              </h3>
              <pre className="mt-3 overflow-x-auto rounded-md border border-border bg-elevated p-4 font-mono text-xs leading-6 text-ink">
                {buildSampleText(result)}
              </pre>
            </section>
          </FadeIn>
        )}

        <FadeIn>
          <section className="mt-20">
            <h2 className="font-serif text-2xl font-semibold tracking-tight text-ink">
              {c.algo_heading}
            </h2>
            <div className="mt-6 max-w-prose space-y-4 leading-relaxed text-muted">
              {c.algo_paragraphs.map((p, i) => (
                <p key={i}>{p}</p>
              ))}
              <p>
                <a
                  href={c.algo_link_href}
                  target="_blank"
                  rel="noreferrer"
                  className="text-accent underline-offset-4 hover:underline"
                >
                  {c.algo_link_label} →
                </a>
              </p>
            </div>
          </section>
        </FadeIn>
      </div>
    </>
  );
}

function Stats({
  result,
  bpm,
  c,
}: {
  result: ProcessResult;
  bpm: number;
  c: (typeof PLAYER)[Lang];
}) {
  const dur = estimateDuration(result.sDurs, result.bDurs, bpm);
  const { ab } = countDissonances(result);
  const semiA = countAltoSemitones(result);
  const items = [
    { val: result.tetras.length, lbl: c.stat_tetras },
    { val: dur, lbl: c.stat_duration },
    { val: `${result.seq.length} bp`, lbl: c.stat_bases },
    { val: `${ab}/${result.tetras.length}`, lbl: c.stat_ab_diss },
    { val: semiA, lbl: c.stat_alto_semi },
  ];
  return (
    <dl className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-5">
      {items.map((s, i) => (
        <div
          key={i}
          className="rounded-md border border-border bg-elevated p-3 text-center"
        >
          <dt className="text-[0.65rem] font-semibold uppercase tracking-[0.15em] text-subtle">
            {s.lbl}
          </dt>
          <dd className="mt-1 font-serif text-xl font-semibold text-ink">
            {s.val}
          </dd>
        </div>
      ))}
    </dl>
  );
}

function buildSampleText(result: ProcessResult): string {
  const n = Math.min(8, result.tetras.length);
  const pad = (s: string, w: number) => s.padEnd(w);
  const lines = [`${pad("Tetra", 7)}${pad("S", 6)}${pad("A", 6)}${pad("T", 6)}B`];
  for (let i = 0; i < n; i++) {
    lines.push(
      pad(result.tetras[i], 7) +
        pad(midiName(result.sNotes[i]), 6) +
        pad(midiName(result.aNotes[i]), 6) +
        pad(midiName(result.tNotes[i]), 6) +
        midiName(result.bNotes[i]),
    );
  }
  return lines.join("\n");
}
