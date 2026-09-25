"use client";

import { CircleDotIcon, EraserIcon, HandIcon, PaintbrushIcon, Redo2Icon, Undo2Icon } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";

export type Tool = "pan" | "add" | "remove" | "circle";

const TOOLS: { value: Tool; label: string; hint: string; icon: typeof HandIcon }[] = [
  { value: "pan", label: "Pan", hint: "Drag to move the map", icon: HandIcon },
  { value: "add", label: "Paint", hint: "Click or drag across hexagons to add them", icon: PaintbrushIcon },
  { value: "remove", label: "Erase", hint: "Click or drag across hexagons to remove them", icon: EraserIcon },
  { value: "circle", label: "Circle", hint: "Click the map to set a centre, then fill a radius", icon: CircleDotIcon },
];

/** Tool picker + undo/redo shared by the service-area and zone editors. */
export function PaintToolbar({
  tool,
  onTool,
  canUndo,
  canRedo,
  onUndo,
  onRedo,
  tools = ["pan", "add", "remove", "circle"],
}: {
  tool: Tool;
  onTool: (t: Tool) => void;
  canUndo: boolean;
  canRedo: boolean;
  onUndo: () => void;
  onRedo: () => void;
  tools?: Tool[];
}) {
  return (
    <div className="flex flex-wrap items-center gap-1">
      <div role="radiogroup" aria-label="Map tool" className="inline-flex rounded-lg bg-muted p-1">
        {TOOLS.filter((t) => tools.includes(t.value)).map((t) => {
          const Icon = t.icon;
          const isActive = tool === t.value;
          return (
            <Tooltip key={t.value}>
              <TooltipTrigger asChild>
                <button
                  type="button"
                  role="radio"
                  aria-checked={isActive}
                  onClick={() => onTool(t.value)}
                  className={cn(
                    "inline-flex items-center gap-1.5 rounded-md px-2.5 py-1.5 text-sm font-medium text-navy-700 transition-colors",
                    isActive && "bg-card text-coral-600 shadow-sm",
                  )}
                >
                  <Icon className="size-4" /> <span className="hidden sm:inline">{t.label}</span>
                </button>
              </TooltipTrigger>
              <TooltipContent>{t.hint}</TooltipContent>
            </Tooltip>
          );
        })}
      </div>
      <Button type="button" variant="ghost" size="icon-sm" onClick={onUndo} disabled={!canUndo} aria-label="Undo">
        <Undo2Icon />
      </Button>
      <Button type="button" variant="ghost" size="icon-sm" onClick={onRedo} disabled={!canRedo} aria-label="Redo">
        <Redo2Icon />
      </Button>
    </div>
  );
}
