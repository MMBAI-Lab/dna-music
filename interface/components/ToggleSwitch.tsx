"use client";

interface ToggleSwitchProps {
  checked: boolean;
  label: string;
  fullName?: string;
  onSelect: () => void;
}

export default function ToggleSwitch({
  checked,
  label,
  fullName,
  onSelect,
}: ToggleSwitchProps) {
  return (
    <button
      type="button"
      onClick={onSelect}
      role="radio"
      aria-checked={checked}
      aria-label={fullName ?? label}
      title={fullName}
      className="group flex select-none flex-col items-center gap-1.5 rounded-sm p-1 focus:outline-none focus-visible:ring-2 focus-visible:ring-accent"
    >
      {/* LED */}
      <span
        aria-hidden
        className="block h-2 w-2 rounded-full transition-shadow"
        style={{
          background: checked
            ? "rgb(var(--accent))"
            : "rgba(80, 80, 80, 0.45)",
          boxShadow: checked
            ? "0 0 8px 1px rgba(var(--accent) / 0.7), inset 0 0 1px rgba(255,255,255,0.5)"
            : "inset 0 0 2px rgba(0,0,0,0.6)",
        }}
      />

      {/* Switch body */}
      <span
        aria-hidden
        className="relative block h-14 w-7 rounded-sm border border-black/70"
        style={{
          background:
            "linear-gradient(to bottom, #1f1f1f 0%, #0a0a0a 50%, #181818 100%)",
          boxShadow:
            "inset 0 1px 2px rgba(0,0,0,0.7), inset 0 -1px 1px rgba(255,255,255,0.04)",
        }}
      >
        {/* Lever */}
        <span
          className="absolute left-[3px] right-[3px] block h-6 rounded-sm transition-[top] duration-150"
          style={{
            top: checked ? 3 : 27,
            background:
              "linear-gradient(to bottom, #d4d4d4 0%, #888 50%, #555 100%)",
            boxShadow:
              "inset 0 1px 1px rgba(255,255,255,0.4), 0 1px 2px rgba(0,0,0,0.5)",
          }}
        />
      </span>

      {/* Label */}
      <span
        className="font-mono text-[0.7rem] font-bold uppercase tracking-wider tabular-nums"
        style={{
          color: checked
            ? "rgb(var(--accent))"
            : "rgba(170, 170, 170, 0.7)",
        }}
      >
        {label}
      </span>
    </button>
  );
}
