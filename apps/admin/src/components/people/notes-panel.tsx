"use client";

import { Loader2Icon, StickyNoteIcon, Trash2Icon } from "lucide-react";
import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { displayName, formatDateTime } from "@/lib/format";
import type { AdminNote } from "@/lib/types";

import { addNote, deleteNote } from "@/app/(panel)/actions";

/** Internal notes on a person (shared by their driver and account pages): add, read, delete. Never shown in the apps. */
export function NotesPanel({ userId, driverId, notes }: { userId: string; driverId?: string; notes: readonly AdminNote[] }) {
  const [text, setText] = useState("");
  const [isPending, startTransition] = useTransition();
  const [busyId, setBusyId] = useState<string | null>(null);
  const isValid = text.trim().length >= 2 && text.trim().length <= 1000;

  return (
    <div className="flex flex-col gap-3">
      <form
        className="grid gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          if (!isValid) return;
          startTransition(async () => {
            const res = await addNote(userId, text, driverId);
            if (res.ok) {
              toast.success(res.message);
              setText("");
            } else toast.error(res.error);
          });
        }}
      >
        <Textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="e.g. Called 1 Oct: will re-upload the RC tomorrow"
          rows={2}
          maxLength={1000}
          aria-label="New note"
        />
        <div className="flex items-center justify-between gap-2">
          <p className="text-xs text-muted-foreground">Admins only, never shown in the apps.</p>
          <Button type="submit" size="sm" disabled={!isValid || (isPending && busyId === null)}>
            {isPending && busyId === null ? <Loader2Icon className="animate-spin" /> : <StickyNoteIcon />} Add note
          </Button>
        </div>
      </form>
      {notes.length === 0 ? (
        <p className="text-sm text-muted-foreground">No notes yet.</p>
      ) : (
        <ul className="divide-y rounded-lg border">
          {notes.map((n) => (
            <li key={n.id} className="group flex gap-2 px-3 py-2.5">
              <div className="min-w-0 flex-1">
                <p className="text-sm whitespace-pre-wrap text-navy-900">{n.body}</p>
                <p className="mt-0.5 text-xs text-muted-foreground">
                  {n.author ? displayName(n.author) : "Former admin"} · {formatDateTime(n.createdAt)}
                </p>
              </div>
              <Button
                size="icon-sm"
                variant="ghost"
                className="text-muted-foreground opacity-60 group-hover:opacity-100 hover:text-error"
                aria-label="Delete note"
                disabled={isPending}
                onClick={() => {
                  setBusyId(n.id);
                  startTransition(async () => {
                    const res = await deleteNote(n.id, userId, driverId);
                    if (res.ok) toast.success(res.message);
                    else toast.error(res.error);
                    setBusyId(null);
                  });
                }}
              >
                {isPending && busyId === n.id ? <Loader2Icon className="animate-spin" /> : <Trash2Icon />}
              </Button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
