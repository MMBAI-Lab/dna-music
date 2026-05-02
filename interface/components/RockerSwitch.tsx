"use client";

interface RockerSwitchProps<T extends string | number> {
  value: T;
  options: readonly T[];
  topLabel?: string;
  ariaLabel?: string;
  width?: number;
  onChange: (v: T) => void;
}

/**
 * Vertical rocker switch with up/down arrow halves.
 * Inspired by automotive mode-rocker switches (BMW SPORT/COMFORT, etc).
 * Generic over the option type — handles any number of options ≥ 2.
 */
export default function RockerSwitch<T extends string | number>({
  value,
  options,
  topLabel,
  ariaLabel,
  width = 76,
  onChange,
}: RockerSwitchProps<T>) {
  const idx = Math.max(0, options.indexOf(value));
  const last = options.length - 1;
  const canUp = idx < last;
  const canDown = idx > 0;

  function step(delta: -1 | 1) {
    const next = idx + delta;
    if (next >= 0 && next <= last) onChange(options[next]);
  }

  function onKey(e: React.KeyboardEvent) {
    if (e.key === "ArrowUp" || e.key === "ArrowRight") {
      e.preventDefault();
      if (canUp) step(1);
    } else if (e.key === "ArrowDown" || e.key === "ArrowLeft") {
      e.preventDefault();
      if (canDown) step(-1);
    } else if (e.key === "Home") {
      e.preventDefault();
      onChange(options[0]);
    } else if (e.key === "End") {
      e.preventDefault();
      onChange(options[last]);
    }
  }

  return (
    <div
      role="group"
      aria-label={ariaLabel ?? "selector"}
      tabIndex={0}
      onKeyDown={onKey}
      className="relative flex select-none flex-col rounded-md border border-black/80 focus:outline-none focus-visible:ring-2 focus-visible:ring-accent"
      style={{
        width,
        background:
          "linear-gradient(to bottom, #2a2a2a 0%, #161616 50%, #232323 100%)",
        boxShadow:
          "0 6px 12px rgba(0,0,0,0.65), inset 0 1px 1px rgba(255,255,255,0.08), inset 0 -1px 1px rgba(0,0,0,0.5)",
      }}
    >
      {/* Engraved top label (like "SPORT") */}
      {topLabel && (
        <div className="pt-2 pb-1 text-center">
          <span
            className="font-mono text-[0.55rem] font-bold uppercase tracking-[0.3em]"
            style={{
              color: "rgba(220,220,220,0.55)",
              textShadow:
                "0 1px 0 rgba(0,0,0,0.85), 0 -1px 0 rgba(255,255,255,0.06)",
            }}
          >
            {topLabel}
          </span>
        </div>
      )}

      {/* Rocker body — chrome plate with two arrow buttons */}
      <div
        className="relative mx-2 mb-2 flex flex-1 flex-col overflow-hidden rounded-sm border border-black/70"
        style={{
          background:
            "linear-gradient(to bottom, #b0b0b0 0%, #6c6c6c 50%, #4a4a4a 100%)",
          boxShadow:
            "0 2px 4px rgba(0,0,0,0.6), inset 0 1px 1px rgba(255,255,255,0.4), inset 0 -1px 1px rgba(0,0,0,0.4)",
        }}
      >
        <RockerButton
          direction="up"
          disabled={!canUp}
          onClick={() => step(1)}
        />
        {/* Groove between halves */}
        <div
          aria-hidden
          className="h-[2px]"
          style={{
            background:
              "linear-gradient(to bottom, rgba(0,0,0,0.55), rgba(0,0,0,0.85), rgba(0,0,0,0.55))",
            boxShadow:
              "0 1px 0 rgba(255,255,255,0.18), inset 0 1px 1px rgba(0,0,0,0.6)",
          }}
        />
        <RockerButton
          direction="down"
          disabled={!canDown}
          onClick={() => step(-1)}
        />
      </div>
    </div>
  );
}

function RockerButton({
  direction,
  disabled,
  onClick,
}: {
  direction: "up" | "down";
  disabled: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={direction === "up" ? "next" : "previous"}
      className={`group relative flex h-1/2 items-center justify-center transition-[transform,filter] active:scale-[0.98] ${
        disabled ? "cursor-not-allowed" : "cursor-pointer"
      }`}
      style={{
        background:
          direction === "up"
            ? "linear-gradient(to bottom, #cfcfcf 0%, #8a8a8a 100%)"
            : "linear-gradient(to top, #cfcfcf 0%, #8a8a8a 100%)",
      }}
    >
      {/* Specular highlight on hover */}
      <span
        aria-hidden
        className="pointer-events-none absolute inset-0 opacity-0 transition-opacity group-hover:opacity-100 group-disabled:opacity-0"
        style={{
          background:
            "radial-gradient(ellipse at center, rgba(var(--accent) / 0.28) 0%, transparent 70%)",
        }}
      />
      {/* Engraved arrow */}
      <Arrow direction={direction} disabled={disabled} />
    </button>
  );
}

function Arrow({
  direction,
  disabled,
}: {
  direction: "up" | "down";
  disabled: boolean;
}) {
  const fill = disabled ? "rgba(60,60,60,0.4)" : "rgba(20,20,20,0.85)";
  const points = direction === "up" ? "8,2 14,12 2,12" : "2,2 14,2 8,12";
  return (
    <svg
      width="16"
      height="14"
      viewBox="0 0 16 14"
      aria-hidden
      style={{
        filter: disabled
          ? "none"
          : "drop-shadow(0 1px 0 rgba(255,255,255,0.4))",
      }}
    >
      <polygon points={points} fill={fill} />
    </svg>
  );
}