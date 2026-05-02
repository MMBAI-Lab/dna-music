"use client";

import { useRef, useState } from "react";

interface KnobProps {
  value: number;
  min: number;
  max: number;
  step?: number;
  size?: number;
  label?: string;
  unit?: string;
  ariaLabel?: string;
  onChange: (v: number) => void;
}

const SWEEP = 270; // total rotation degrees from min to max (-135° → +135°)
const PIXELS_FOR_FULL_SWEEP = 220;

export default function Knob({
  value,
  min,
  max,
  step = 1,
  size = 96,
  label,
  unit,
  ariaLabel,
  onChange,
}: KnobProps) {
  const range = max - min;
  const angle = ((value - min) / range) * SWEEP - SWEEP / 2;

  const dragRef = useRef<{ startY: number; startVal: number } | null>(null);
  const [dragging, setDragging] = useState(false);

  const clamp = (v: number) => Math.min(max, Math.max(min, v));
  const snap = (v: number) => Math.round(v / step) * step;

  function onPointerDown(e: React.PointerEvent) {
    e.preventDefault();
    e.currentTarget.setPointerCapture(e.pointerId);
    dragRef.current = { startY: e.clientY, startVal: value };
    setDragging(true);
  }

  function onPointerMove(e: React.PointerEvent) {
    if (!dragRef.current) return;
    const { startY, startVal } = dragRef.current;
    const dy = startY - e.clientY;
    const next = clamp(snap(startVal + (dy * range) / PIXELS_FOR_FULL_SWEEP));
    if (next !== value) onChange(next);
  }

  function onPointerUp(e: React.PointerEvent) {
    dragRef.current = null;
    setDragging(false);
    e.currentTarget.releasePointerCapture(e.pointerId);
  }

  function onWheel(e: React.WheelEvent) {
    if (e.deltaY === 0) return;
    const delta = e.deltaY > 0 ? -step : step;
    onChange(clamp(value + delta));
  }

  function onKeyDown(e: React.KeyboardEvent) {
    let delta = 0;
    if (e.key === "ArrowUp" || e.key === "ArrowRight") delta = step;
    else if (e.key === "ArrowDown" || e.key === "ArrowLeft") delta = -step;
    else if (e.key === "PageUp") delta = step * 10;
    else if (e.key === "PageDown") delta = -step * 10;
    else if (e.key === "Home") {
      e.preventDefault();
      return onChange(min);
    } else if (e.key === "End") {
      e.preventDefault();
      return onChange(max);
    }
    if (delta !== 0) {
      e.preventDefault();
      onChange(clamp(value + delta));
    }
  }

  // Tick marks around the knob (every 30°), to suggest a calibrated dial.
  const ticks = Array.from({ length: 10 }, (_, i) => -135 + i * 30);

  return (
    <div className="flex flex-col items-center gap-2 select-none">
      {label && (
        <span className="text-[0.6rem] font-bold uppercase tracking-[0.3em] text-zinc-300">
          {label}
        </span>
      )}
      <div
        role="slider"
        aria-label={ariaLabel || label || "knob"}
        aria-valuemin={min}
        aria-valuemax={max}
        aria-valuenow={value}
        tabIndex={0}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onWheel={onWheel}
        onKeyDown={onKeyDown}
        className={`relative touch-none focus:outline-none focus-visible:ring-2 focus-visible:ring-accent ${
          dragging ? "cursor-grabbing" : "cursor-grab"
        }`}
        style={{ width: size, height: size }}
      >
        {/* Tick ring */}
        <div className="absolute inset-0">
          {ticks.map((t, i) => (
            <span
              key={i}
              className="absolute left-1/2 top-1/2 block h-[6%] w-[2px] origin-top -translate-x-1/2"
              style={{
                transform: `translate(-50%, 0) rotate(${t}deg) translateY(${size * 0.42}px)`,
                background: "rgba(180,180,180,0.35)",
              }}
            />
          ))}
        </div>

        {/* Outer faceplate */}
        <div
          className="absolute rounded-full"
          style={{
            inset: "8%",
            background:
              "radial-gradient(circle at 30% 25%, #4a4a4a 0%, #1a1a1a 60%, #050505 100%)",
            boxShadow:
              "0 8px 16px rgba(0,0,0,0.65), inset 0 -2px 5px rgba(0,0,0,0.7), inset 0 2px 3px rgba(255,255,255,0.08)",
          }}
        />

        {/* Knurled inner cap */}
        <div
          className="absolute rounded-full"
          style={{
            inset: "20%",
            background:
              "radial-gradient(circle at 35% 30%, #2c2c2c, #0a0a0a 90%)",
            boxShadow:
              "inset 0 1px 2px rgba(255,255,255,0.06), inset 0 -2px 3px rgba(0,0,0,0.7)",
          }}
        />

        {/* Indicator stripe (rotates with value) */}
        <div
          className="absolute inset-0"
          style={{
            transform: `rotate(${angle}deg)`,
            transition: dragging ? "none" : "transform 0.08s ease-out",
          }}
        >
          <span
            className="absolute left-1/2 block rounded-sm"
            style={{
              top: "12%",
              width: 3,
              height: "22%",
              transform: "translateX(-50%)",
              background: "linear-gradient(to bottom, #f5e8c4, #b88e3c)",
              boxShadow:
                "0 0 6px rgba(245,232,196,0.5), 0 1px 1px rgba(0,0,0,0.6)",
            }}
          />
        </div>
      </div>
      <div className="flex items-baseline gap-1.5 font-mono leading-none">
        <span className="text-2xl font-bold text-zinc-100 tabular-nums">
          {value}
        </span>
        {unit && (
          <span className="text-[0.6rem] uppercase tracking-[0.25em] text-zinc-400">
            {unit}
          </span>
        )}
      </div>
    </div>
  );
}
