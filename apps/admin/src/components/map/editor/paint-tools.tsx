"use client";

import { CircleDotIcon, EraserIcon, HandIcon, PaintbrushIcon, PentagonIcon, Redo2Icon, Undo2Icon } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { BRUSH_SIZES } from "@/lib/hex";
import { cn } from "@/lib/utils";

export type Tool = "pan" | "add" | "remove" | "polygon" | "circle";

const TOOLS: { value: Tool; label: string; hint: string; key: string; icon: typeof HandIcon }[] = [
  { value: "pan", label: "Pan", hint: "Drag to move the map", key: "H / hold Space", icon: HandIcon },
  { value: "add", label: "Paint", hint: "Click or drag to add hexagons", key: "P", icon: PaintbrushIcon },
  { value: "remove", label: "Erase", hint: "Click or drag to remove hexagons", key: "E", icon: EraserIcon },
  { value: "polygon", label: "Draw area", hint: "Click points; double-click or click the first point to close", key: "D", icon: PentagonIcon },
  { value: "circle", label: "Circle", hint: "Click the map to set a centre, then fill a radius", key: "C", icon: CircleDotIcon },
];

/** Tools, brush size and undo/redo for the hex editors. */
export function PaintToolbar({
  tool,
  onTool,
  brush,
  onBrush,
  canUndo,
  canRedo,
  onUndo,
  onRedo,
}: {
  tool: Tool;
  onTool: (t: Tool) => void;
  brush: number;
  onBrush: (k: number) => void;
  canUndo: boolean;
  canRedo: boolean;
  onUndo: () => void;
  onRedo: () => void;
}) {
  const isBrushTool = tool === "add" || tool === "remove";
  return (
    <div className="flex flex-wrap items-center gap-2">
      <div role="radiogroup" aria-label="Map tool" className="inline-flex rounded-lg bg-muted p-1">
        {TOOLS.map((t) => {
          const Icon = t.icon;
          const isActive = tool === t.value;
          return (
            <Tooltip key={t.value}>
              <TooltipTrigger asChild>
                <button
                  type="button"
                  role="radio"
                  aria-checked={isActive}
                  aria-keyshortcuts={t.key}
                  onClick={() => onTool(t.value)}
                  className={cn(
                    "inline-flex items-center gap-1.5 rounded-md px-2.5 py-1.5 text-sm font-medium text-navy-700 transition-colors",
                    isActive && "bg-card text-coral-600 shadow-sm",
                  )}
                >
                  <Icon className="size-4" /> <span className="hidden md:inline">{t.label}</span>
                </button>
              </TooltipTrigger>
              <TooltipContent>
                {t.hint} · <kbd>{t.key}</kbd>
              </TooltipContent>
            </Tooltip>
          );
        })}
      </div>
      <div
        role="radiogroup"
        aria-label="Brush size"
        className={cn("inline-flex items-center rounded-lg bg-muted p-1 text-xs transition-opacity", !isBrushTool && "opacity-50")}
      >
        <span className="px-1.5 text-muted-foreground">Brush</span>
        {BRUSH_SIZES.map((b) => (
          <button
            key={b.k}
            type="button"
            role="radio"
            aria-checked={brush === b.k}
            aria-label={`${b.cells} hexagon${b.cells > 1 ? "s" : ""}`}
            onClick={() => onBrush(b.k)}
            className={cn(
              "min-w-8 rounded-md px-2 py-1 font-medium tabular-nums text-navy-700",
              brush === b.k && "bg-card text-coral-600 shadow-sm",
            )}
          >
            {b.cells}
          </button>
        ))}
      </div>
      <div className="flex">
        <Button type="button" variant="ghost" size="icon-sm" onClick={onUndo} disabled={!canUndo} aria-label="Undo (Ctrl+Z)">
          <Undo2Icon />
        </Button>
        <Button type="button" variant="ghost" size="icon-sm" onClick={onRedo} disabled={!canRedo} aria-label="Redo (Ctrl+Shift+Z)">
          <Redo2Icon />
        </Button>
      </div>
    </div>
  );
}
