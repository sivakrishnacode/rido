"use client";

import { CheckIcon, Loader2Icon, PauseIcon, PlayIcon, XIcon } from "lucide-react";
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
import type { DriverStatus, KycDocType, KycStatus } from "@/lib/types";

import { reviewDocument, setDriverStatus, type ActionResult } from "../../actions";

function notify(res: ActionResult): boolean {
  if (res.ok) toast.success(res.message);
  else toast.error(res.error);
  return res.ok;
}

/** Approve / Put on hold / Reactivate → PATCH /admin/drivers/:id. */
export function DriverStatusActions({ driverId, status, name }: { driverId: string; status: DriverStatus; name: string }) {
  const [isPending, startTransition] = useTransition();
  const [pendingTarget, setPendingTarget] = useState<DriverStatus | null>(null);
  const [isHoldOpen, setHoldOpen] = useState(false);

  function change(target: DriverStatus, after?: () => void) {
    setPendingTarget(target);
    startTransition(async () => {
      if (notify(await setDriverStatus(driverId, target))) after?.();
      setPendingTarget(null);
    });
  }

  const spinner = (t: DriverStatus) => (isPending && pendingTarget === t ? <Loader2Icon className="animate-spin" /> : null);

  return (
    <>
      {status === "PENDING" && (
        <Button onClick={() => change("APPROVED")} disabled={isPending}>
          {spinner("APPROVED") ?? <CheckIcon />} Approve
        </Button>
      )}
      {(status === "ON_HOLD" || status === "REJECTED") && (
        <Button onClick={() => change("APPROVED")} disabled={isPending}>
          {spinner("APPROVED") ?? <PlayIcon />} Reactivate
        </Button>
      )}
      {(status === "APPROVED" || status === "PENDING") && (
        <Button variant="outline" onClick={() => setHoldOpen(true)} disabled={isPending}>
          <PauseIcon /> Put on hold
        </Button>
      )}

      <Dialog open={isHoldOpen} onOpenChange={setHoldOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Put {name} on hold?</DialogTitle>
            <DialogDescription>
              The driver is taken offline and can&apos;t receive rides until you reactivate the account.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline">Cancel</Button>
            </DialogClose>
            <Button variant="destructive" disabled={isPending} onClick={() => change("ON_HOLD", () => setHoldOpen(false))}>
              {spinner("ON_HOLD") ?? <PauseIcon />} Put on hold
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}

/** Verify / Reject (with reason) one KYC document → POST /admin/drivers/:id/documents/:type. */
export function DocumentActions({
  driverId,
  type,
  label,
  status,
}: {
  driverId: string;
  type: KycDocType;
  label: string;
  status: KycStatus;
}) {
  const [isPending, startTransition] = useTransition();
  const [action, setAction] = useState<"VERIFIED" | "REJECTED" | null>(null);
  const [isRejectOpen, setRejectOpen] = useState(false);
  const [reason, setReason] = useState("");
  const isReasonValid = reason.trim().length >= 3 && reason.trim().length <= 200;

  function review(next: "VERIFIED" | "REJECTED") {
    setAction(next);
    startTransition(async () => {
      const ok = notify(await reviewDocument(driverId, type, next, next === "REJECTED" ? reason : undefined));
      if (ok && next === "REJECTED") {
        setRejectOpen(false);
        setReason("");
      }
      setAction(null);
    });
  }

  return (
    <div className="flex shrink-0 gap-2">
      <Button
        size="sm"
        variant="outline"
        className="border-success/30 text-success-text hover:bg-success-tint hover:text-success-text"
        disabled={isPending || status === "VERIFIED"}
        onClick={() => review("VERIFIED")}
      >
        {isPending && action === "VERIFIED" ? <Loader2Icon className="animate-spin" /> : <CheckIcon />} Verify
      </Button>
      <Button
        size="sm"
        variant="outline"
        className="border-error/30 text-error hover:bg-error-tint hover:text-error"
        disabled={isPending || status === "REJECTED"}
        onClick={() => setRejectOpen(true)}
      >
        <XIcon /> Reject
      </Button>

      <Dialog open={isRejectOpen} onOpenChange={setRejectOpen}>
        <DialogContent>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              if (isReasonValid) review("REJECTED");
            }}
            className="grid gap-4"
          >
            <DialogHeader>
              <DialogTitle>Reject {label}?</DialogTitle>
              <DialogDescription>
                The driver sees this reason in the app and can upload the document again. Rejecting any document marks the
                driver as rejected.
              </DialogDescription>
            </DialogHeader>
            <div className="grid gap-2">
              <Label htmlFor={`reason-${type}`}>Reason</Label>
              <Textarea
                id={`reason-${type}`}
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder="e.g. Photo is blurred, please upload a clearer image"
                maxLength={200}
                rows={3}
                autoFocus
              />
              <p className="text-xs text-muted-foreground">{reason.trim().length}/200 · at least 3 characters</p>
            </div>
            <DialogFooter>
              <DialogClose asChild>
                <Button type="button" variant="outline">
                  Cancel
                </Button>
              </DialogClose>
              <Button type="submit" variant="destructive" disabled={!isReasonValid || isPending}>
                {isPending && action === "REJECTED" ? <Loader2Icon className="animate-spin" /> : <XIcon />} Reject document
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
