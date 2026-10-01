import { CheckIcon, CircleDashedIcon, ClockIcon, XIcon } from "lucide-react";

import { docLabel } from "@/lib/format";
import type { ApprovalChecklist, CheckState } from "@/lib/types";
import { cn } from "@/lib/utils";

const STATE: Record<CheckState, { icon: typeof CheckIcon; className: string; word: string }> = {
  DONE: { icon: CheckIcon, className: "border-success/30 bg-success-tint text-success-text", word: "done" },
  REVIEW: { icon: ClockIcon, className: "border-warning/30 bg-warning-tint text-warning-text", word: "in review" },
  TODO: { icon: CircleDashedIcon, className: "border-border bg-muted text-muted-foreground", word: "not done" },
  FAILED: { icon: XIcon, className: "border-error/30 bg-error-tint text-error", word: "rejected" },
};

export function checkLabel(key: ApprovalChecklist["checks"][number]["key"]): string {
  return key === "IDENTITY" ? "Identity" : key === "VEHICLE_RC" ? "RC" : docLabel(key);
}

/** One chip per approval step (RC, insurance, identity) coloured by its state. */
export function ApprovalChecks({ checklist, className }: { checklist: ApprovalChecklist; className?: string }) {
  return (
    <ul className={cn("flex flex-wrap gap-1.5", className)} aria-label="Approval checks">
      {checklist.checks.map((c) => {
        const s = STATE[c.state];
        const Icon = s.icon;
        return (
          <li
            key={c.key}
            className={cn("inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-xs font-medium", s.className)}
            title={`${checkLabel(c.key)}: ${s.word}`}
          >
            <Icon className="size-3" aria-hidden />
            {checkLabel(c.key)}
            <span className="sr-only">: {s.word}</span>
          </li>
        );
      })}
    </ul>
  );
}

/** "RC not uploaded · Identity in review": what still stands between the driver and approval. */
export function missingChecks(checklist: ApprovalChecklist): string {
  const words: Record<CheckState, string> = { DONE: "", REVIEW: "in review", TODO: "not done", FAILED: "rejected" };
  return checklist.checks
    .filter((c) => c.state !== "DONE")
    .map((c) => `${checkLabel(c.key)} ${c.key !== "IDENTITY" && c.state === "TODO" ? "not uploaded" : words[c.state]}`)
    .join(" · ");
}
