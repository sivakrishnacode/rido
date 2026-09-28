"use client";

import { CheckCheckIcon, HandIcon, Loader2Icon } from "lucide-react";
import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { SosStatus } from "@/lib/safety";

import { acknowledgeSos, resolveSos } from "../actions";

/** Acknowledge an open SOS; resolve (with a note) or mark a false alarm. Both are audit logged by the API. */
export function SosActions({ id, tripId, status }: { id: string; tripId: string; status: SosStatus }) {
  const [isOpen, setOpen] = useState(false);
  const [note, setNote] = useState("");
  const [isPending, startTransition] = useTransition();

  if (status === "RESOLVED" || status === "FALSE_ALARM") return null;

  function ack() {
    startTransition(async () => {
      const res = await acknowledgeSos(id, tripId);
      if (res.ok) toast.success(res.message);
      else toast.error(res.error);
    });
  }

  function close(to: "RESOLVED" | "FALSE_ALARM") {
    startTransition(async () => {
      const res = await resolveSos(id, tripId, to, note);
      if (res.ok) {
        toast.success(res.message);
        setOpen(false);
        setNote("");
      } else toast.error(res.error);
    });
  }

  return (
    <div className="relative z-10 flex flex-wrap justify-end gap-2">
      {status === "OPEN" && (
        <Button size="sm" onClick={ack} disabled={isPending}>
          {isPending ? <Loader2Icon className="animate-spin" /> : <HandIcon />} Acknowledge
        </Button>
      )}
      <Dialog open={isOpen} onOpenChange={setOpen}>
        <Button size="sm" variant="outline" onClick={() => setOpen(true)} disabled={isPending}>
          <CheckCheckIcon /> Resolve
        </Button>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Close this SOS</DialogTitle>
            <DialogDescription>Say what happened and what you did. It is kept with the SOS and in the audit log.</DialogDescription>
          </DialogHeader>
          <div className="space-y-2">
            <Label htmlFor={`sos-note-${id}`}>Note</Label>
            <Textarea
              id={`sos-note-${id}`}
              value={note}
              maxLength={500}
              onChange={(e) => setNote(e.target.value)}
              placeholder="e.g. Called the rider: the driver stopped for fuel, all fine"
            />
          </div>
          <DialogFooter className="gap-2">
            <DialogClose asChild>
              <Button variant="outline">Cancel</Button>
            </DialogClose>
            <Button variant="outline" onClick={() => close("FALSE_ALARM")} disabled={isPending}>
              False alarm
            </Button>
            <Button onClick={() => close("RESOLVED")} disabled={isPending}>
              {isPending ? <Loader2Icon className="animate-spin" /> : <CheckCheckIcon />} Resolve
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
