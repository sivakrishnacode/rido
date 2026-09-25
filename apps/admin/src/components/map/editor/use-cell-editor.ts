"use client";

import { useCallback, useEffect, useRef, useState } from "react";

import { applyCells, historyInit, historyPush, historyRedo, historyUndo, type CellHistory } from "@/lib/hex";

import type { Tool } from "./paint-tools";

/**
 * Cell-set editing with strokes (a drag = one undo step), undo/redo and keyboard shortcuts (Ctrl+Z / Ctrl+Shift+Z).
 */
export type CellEditor = ReturnType<typeof useCellEditor>;

export function useCellEditor(initial: readonly string[]) {
  const [history, setHistory] = useState<CellHistory>(() => historyInit([...initial].sort()));
  const [stroke, setStroke] = useState<string[] | null>(null);
  const strokeRef = useRef<string[] | null>(null);
  const [tool, setTool] = useState<Tool>("pan");

  const cells = stroke ?? history.present;

  const reset = useCallback((next: readonly string[]) => setHistory(historyInit([...next].sort())), []);
  const commit = useCallback((next: readonly string[]) => setHistory((h) => historyPush(h, next)), []);
  const undo = useCallback(() => setHistory(historyUndo), []);
  const redo = useCallback(() => setHistory(historyRedo), []);

  const paint = {
    mode: tool === "add" || tool === "remove" ? tool : null,
    onStrokeStart: () => {
      strokeRef.current = [...history.present];
      setStroke(strokeRef.current);
    },
    onCells: (cells: readonly string[], mode: "add" | "remove") => {
      if (!strokeRef.current) return;
      strokeRef.current = applyCells(strokeRef.current, cells, mode);
      setStroke(strokeRef.current);
    },
    onStrokeEnd: () => {
      const done = strokeRef.current;
      strokeRef.current = null;
      setStroke(null);
      if (done) commit(done);
    },
  } as const;

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      const target = e.target as HTMLElement | null;
      if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")) return;
      if (!(e.ctrlKey || e.metaKey) || e.key.toLowerCase() !== "z") return;
      e.preventDefault();
      if (e.shiftKey) redo();
      else undo();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [undo, redo]);

  return {
    cells,
    tool,
    setTool,
    paint,
    commit,
    reset,
    undo,
    redo,
    canUndo: history.past.length > 0,
    canRedo: history.future.length > 0,
  };
}
