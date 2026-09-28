"use client";

import { CheckIcon, Loader2Icon } from "lucide-react";
import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

import { clearTripReview } from "../../actions";

/** "Mark reviewed" on a flagged trip → PATCH /admin/trips/:id/review (the flag's reason stays in the note). */
export function MarkReviewedButton({ tripId }: { tripId: string }) {
  const [isOpen, setOpen] = useState(false);
  const [note, setNote] = useState("");
  const [isPending, startTransition] = useTransition();

  function submit() {
    startTransition(async () => {
      const res = await clearTripReview(tripId, note);
      if (res.ok) {
        toast.success(res.message);
        setOpen(false);
      } else toast.error(res.error);
    });
  }

  return (
    <Dialog open={isOpen} onOpenChange={setOpen}>
      <Button size="sm" variant="outline" onClick={() => setOpen(true)}>
        <CheckIcon /> Mark reviewed
      </Button>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Mark this trip as reviewed?</DialogTitle>
          <DialogDescription>It leaves the Needs review list. The fare doesn&apos;t change.</DialogDescription>
        </DialogHeader>
        <div className="space-y-2">
          <Label htmlFor="review-note">Note (optional)</Label>
          <Textarea id="review-note" value={note} maxLength={300} onChange={(e) => setNote(e.target.value)} placeholder="e.g. Called the driver: detour for a road block" />
        </div>
        <DialogFooter>
          <DialogClose asChild>
            <Button variant="outline">Cancel</Button>
          </DialogClose>
          <Button onClick={submit} disabled={isPending}>
            {isPending ? <Loader2Icon className="animate-spin" /> : <CheckIcon />} Mark reviewed
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
