"use client";

import { useRef, useState } from "react";

interface FaderProps {
  value: number;
  min?: number;
  max?: number;
  step?: number;
  label: string;
  subLabel?: string;
  ariaLabel?: string;
  height?: number;
  onChange: (v: number) => void;
}

const TRACK_PADDING = 6;

export default function Fader({
  value,
  min = 0,
  max = 100,
  step = 1,
  label,
  subLabel,
  ariaLabel,
  height = 150,
  onChange,
}: FaderProps) {
  const range = max - min;
  const trackRef = useRef<HTMLDivElement | null>(null);
  const [dragging, setDragging] = useState(false);

  const clamp = (v: number) => Math.min(max, Math.max(min, v));
  const snap = (v: number) => Math.round(v / step) * step;

  function valueFromClientY(clientY: number): number {
    const el = trackRef.current;
    if (!el) return value;
    const rect = el.getBoundingClientRect();
    const usable = rect.height - TRACK_PADDING * 2;
    const fromTop = clientY - rect.top - TRACK_PADDING;
    const ratio = 1 - fromTop / usable;
    return clamp(snap(min + ratio * range));
  }

  function onPointerDown(e: React.PointerEvent) {
    e.preventDefault();
    e.currentTarget.setPointerCapture(e.pointerId);
    setDragging(true);
    onChange(valueFromClientY(e.clientY));
  }

  function onPointerMove(e: React.PointerEvent) {
    if (!dragging) return;
    onChange(valueFromClientY(e.clientY));
  }

  function onPointerUp(e: React.PointerEvent) {
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

  const ratio = (value - min) / range;
  const muted = value === 0;

  // Tick marks every 25% along the track
  const ticks = [0, 0.25, 0.5, 0.75, 1];

  return (
    <div className="flex select-none flex-col items-center gap-1.5">
      <span className="whitespace-nowrap font-mono text-[0.6rem] font-bold uppercase tracking-wider text-zinc-300">
        {label}
      </span>
      {subLabel && (
        <span className="-mt-1 whitespace-nowrap font-mono text-[0.55rem] uppercase tracking-wider text-zinc-500">
          {subLabel}
        </span>
      )}

      <div
        ref={trackRef}
        role="slider"
        aria-label={ariaLabel || label}
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
        className={`relative touch-none rounded-sm border border-black/70 focus:outline-none focus-visible:ring-2 focus-visible:ring-accent ${
          dragging ? "cursor-grabbing" : "cursor-grab"
        }`}
        style={{
          width: 30,
          height,
          background:
            "linear-gradient(to bottom, #1f1f1f 0%, #0a0a0a 50%, #181818 100%)",
          boxShadow:
            "inset 0 1px 2px rgba(0,0,0,0.7), inset 0 -1px 1px rgba(255,255,255,0.04)",
        }}
      >
        {/* Center channel */}
        <span
          aria-hidden
          className="absolute left-1/2 -translate-x-1/2 rounded-sm"
          style={{
            top: TRACK_PADDING,
            bottom: TRACK_PADDING,
            width: 2,
            background:
              "linear-gradient(to bottom, rgba(0,0,0,0.85), rgba(40,40,40,0.6))",
            boxShadow: "inset 0 1px 1px rgba(0,0,0,0.7)",
          }}
        />

        {/* Tick marks */}
        {ticks.map((t, i) => (
          <span
            key={i}
            aria-hidden
            className="absolute right-[3px] block h-[1px] w-[5px]"
            style={{
              top: `calc(${TRACK_PADDING}px + (100% - ${TRACK_PADDING * 2}px) * ${1 - t})`,
              background: "rgba(180,180,180,0.3)",
            }}
          />
        ))}

        {/* Lever */}
        <span
          aria-hidden
          className="absolute left-[2px] right-[2px] block rounded-sm transition-[top] duration-75"
          style={{
            top: `calc(${TRACK_PADDING}px + (100% - ${TRACK_PADDING * 2}px) * ${1 - ratio} - 8px)`,
            height: 16,
            background: muted
              ? "linear-gradient(to bottom, #4a4a4a 0%, #2a2a2a 50%, #1a1a1a 100%)"
              : "linear-gradient(to bottom, #d4d4d4 0%, #888 50%, #555 100%)",
            boxShadow:
              "inset 0 1px 1px rgba(255,255,255,0.4), 0 1px 2px rgba(0,0,0,0.5)",
          }}
        >
          {/* Lever indicator stripe */}
          <span
            className="absolute left-1/2 top-1/2 block h-[2px] w-[60%] -translate-x-1/2 -translate-y-1/2 rounded-sm"
            style={{
              background: muted
                ? "rgba(150,150,150,0.4)"
                : "linear-gradient(to right, rgba(0,0,0,0.5), rgba(0,0,0,0.85), rgba(0,0,0,0.5))",
            }}
          />
        </span>
      </div>

      <span
        className="font-mono text-[0.7rem] font-bold tabular-nums"
        style={{
          color: muted ? "rgba(150,150,150,0.55)" : "rgb(var(--accent))",
        }}
      >
        {value}
      </span>
    </div>
  );
}
