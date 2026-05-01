"use client";

import { useEffect, useRef } from "react";
import DnaHelix from "@/components/DnaHelix";

const DNA_BANDS = [
  { y: 28, dir: 1, size: "text-[10rem] md:text-[18rem]", duration: 7200, opacity: 0.05, rotate: -2 },
  { y: 72, dir: -1, size: "text-[12rem] md:text-[22rem]", duration: 9600, opacity: 0.04, rotate: 1 },
];

const SEQUENCE_POOL = [
  "ATCGATCGGCAATTCGCAGCTAGCTACGATCGTAGCTAGCTACG",
  "GCTAGCATCGCAATTCGGCATCGAATTCGCAGCTAGCTACGAT",
  "TGCAATCGTAGCTAGCTACGTAGCTAGCATGCAGCTACGTACG",
  "ATGCATGCATGCAATCGTAGCTAGCTACGTAGCTACGATCGTA",
];

function makeBand(idx: number) {
  const seed = SEQUENCE_POOL[idx % SEQUENCE_POOL.length];
  return (seed + " ").repeat(20);
}

export default function SonifBackground({ className = "" }: { className?: string }) {
  return (
    <div
      className={`pointer-events-none fixed inset-0 z-0 overflow-hidden ${className}`}
      aria-hidden="true"
    >
      <DnaHelix className="absolute -right-24 top-1/2 hidden h-[150%] -translate-y-1/2 opacity-30 md:block md:w-[680px]" />
      <DnaHelix className="absolute -left-32 top-[10%] h-[60%] opacity-20 md:hidden" />

      <div className="absolute inset-0">
        {DNA_BANDS.map((b, i) => (
          <div
            key={i}
            className="absolute left-0 right-0 whitespace-nowrap font-mono font-semibold tracking-[0.35em]"
            style={{
              top: `${b.y}%`,
              transform: `translateY(-50%) rotate(${b.rotate}deg)`,
              color: "rgb(var(--ink))",
              opacity: b.opacity,
            }}
          >
            <div
              className="sonif-ribbon"
              style={{
                animationDuration: `${b.duration}s`,
                animationDirection: b.dir < 0 ? "reverse" : "normal",
              }}
            >
              <span className={b.size}>{makeBand(i)}</span>
              <span className={b.size}>{makeBand(i)}</span>
            </div>
          </div>
        ))}
      </div>

      <FloatingNotes />

      <style>{`
        .sonif-ribbon {
          display: inline-flex;
          gap: 2rem;
          animation-name: sonif-ribbon-slide;
          animation-timing-function: linear;
          animation-iteration-count: infinite;
          will-change: transform;
        }
        @keyframes sonif-ribbon-slide {
          from { transform: translateX(0); }
          to   { transform: translateX(-50%); }
        }
        @media (prefers-reduced-motion: reduce) {
          .sonif-ribbon { animation: none; }
        }
      `}</style>
    </div>
  );
}

type Note = {
  glyph: string;
  x: number;
  y: number;
  vy: number;
  vx: number;
  size: number;
  rot: number;
  rotV: number;
  alpha: number;
  rgb: [number, number, number];
};

const RED_TONES: [number, number, number][] = [
  [220, 38, 38],
  [239, 68, 68],
  [153, 27, 27],
  [185, 28, 28],
  [251, 113, 133],
];

const NOTE_GLYPHS = ["♩", "♪", "♫", "♬", "♭", "♯", "\u{1D11E}", "\u{1D122}"];

function FloatingNotes() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx2d = canvas.getContext("2d", { alpha: true });
    if (!ctx2d) return;
    const ctx = ctx2d;

    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);

    let width = 0;
    let height = 0;
    let notes: Note[] = [];
    let raf = 0;
    let running = true;
    let lastT = 0;

    function rng() {
      return Math.random();
    }

    function makeNote(belowScreen = false): Note {
      const size = 14 + rng() * 28;
      return {
        glyph: NOTE_GLYPHS[Math.floor(rng() * NOTE_GLYPHS.length)],
        x: rng(),
        y: belowScreen ? height + size + rng() * height : rng() * height,
        vy: -(0.008 + rng() * 0.018),
        vx: (rng() - 0.5) * 0.005,
        size,
        rot: (rng() - 0.5) * 0.4,
        rotV: (rng() - 0.5) * 0.0002,
        alpha: 0.18 + rng() * 0.32,
        rgb: RED_TONES[Math.floor(rng() * RED_TONES.length)],
      };
    }

    function resize() {
      const rect = canvas!.getBoundingClientRect();
      width = rect.width;
      height = rect.height;
      canvas!.width = Math.max(1, Math.floor(width * dpr));
      canvas!.height = Math.max(1, Math.floor(height * dpr));
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

      const target = Math.max(8, Math.round((width * height) / 36000));
      notes = Array.from({ length: target }, () => makeNote());
    }

    function draw(dt: number) {
      ctx.clearRect(0, 0, width, height);
      ctx.textBaseline = "middle";
      ctx.textAlign = "center";

      for (const n of notes) {
        n.y += n.vy * dt;
        n.x += (n.vx * dt) / Math.max(1, width);
        n.rot += n.rotV * dt;

        if (n.y < -n.size * 1.5) {
          Object.assign(n, makeNote(true));
          n.y = height + n.size + 10;
        }
        if (n.x < -0.05) n.x = 1.05;
        if (n.x > 1.05) n.x = -0.05;

        ctx.save();
        ctx.translate(n.x * width, n.y);
        ctx.rotate(n.rot);
        ctx.font = `${n.size}px "Apple Symbols", "Noto Music", "Segoe UI Symbol", "DejaVu Sans", sans-serif`;
        const [r, g, b] = n.rgb;
        ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${n.alpha.toFixed(3)})`;
        ctx.fillText(n.glyph, 0, 0);
        ctx.restore();
      }
    }

    function loop(t: number) {
      if (!running) return;
      const dt = lastT === 0 ? 16 : Math.min(48, t - lastT);
      if (t - lastT >= 1000 / 30) {
        draw(dt);
        lastT = t;
      }
      raf = requestAnimationFrame(loop);
    }

    function start() {
      if (raf || reduce) return;
      running = true;
      lastT = 0;
      raf = requestAnimationFrame(loop);
    }
    function stop() {
      running = false;
      if (raf) cancelAnimationFrame(raf);
      raf = 0;
    }

    resize();
    if (reduce) {
      draw(16);
    } else {
      start();
    }

    const ro = new ResizeObserver(resize);
    ro.observe(canvas);
    const io = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) start();
        else stop();
      },
      { threshold: 0.01 }
    );
    io.observe(canvas);
    const onVis = () => (document.hidden ? stop() : start());
    document.addEventListener("visibilitychange", onVis);

    return () => {
      stop();
      ro.disconnect();
      io.disconnect();
      document.removeEventListener("visibilitychange", onVis);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      className="absolute inset-0 h-full w-full"
    />
  );
}
