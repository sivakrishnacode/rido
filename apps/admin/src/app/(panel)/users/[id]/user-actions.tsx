"use client";

import { BanIcon, Loader2Icon, ShieldCheckIcon } from "lucide-react";
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
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { humanize } from "@/lib/format";
import { ROLES, type Role } from "@/lib/types";

import { setUserBlocked, setUserRole } from "../../actions";

/** Role select with a confirmation dialog → PATCH /admin/users/:id {role}. */
export function RoleControl({ userId, role, name }: { userId: string; role: Role; name: string }) {
  const [target, setTarget] = useState<Role | null>(null);
  const [isPending, startTransition] = useTransition();

  return (
    <>
      <Select value={role} onValueChange={(v) => v !== role && setTarget(v as Role)}>
        <SelectTrigger className="w-40" aria-label="Role">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {ROLES.map((r) => (
            <SelectItem key={r} value={r}>
              {humanize(r)}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      <Dialog open={target !== null} onOpenChange={(open) => !open && setTarget(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              Make {name} {target === "ADMIN" ? "an" : "a"} {target ? humanize(target).toLowerCase() : ""}?
            </DialogTitle>
            <DialogDescription>
              {target === "ADMIN"
                ? "Admins can sign in to this panel and change anything here. Note: phones in ADMIN_PHONES always sign in as admin."
                : "The new role applies from the user's next sign-in. A driver role still needs a driver profile to take rides."}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline">Cancel</Button>
            </DialogClose>
            <Button
              disabled={isPending}
              onClick={() =>
                target &&
                startTransition(async () => {
                  const res = await setUserRole(userId, target);
                  if (res.ok) {
                    toast.success(res.message);
                    setTarget(null);
                  } else toast.error(res.error);
                })
              }
            >
              {isPending && <Loader2Icon className="animate-spin" />} Change role
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}

/** Block (with reason) / Unblock → PATCH /admin/users/:id {isBlocked, blockedReason}. */
export function BlockControl({ userId, isBlocked, name }: { userId: string; isBlocked: boolean; name: string }) {
  const [isOpen, setOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [isPending, startTransition] = useTransition();
  const isReasonValid = reason.trim().length >= 3 && reason.trim().length <= 200;

  function submit(block: boolean) {
    startTransition(async () => {
      const res = await setUserBlocked(userId, block, block ? reason : undefined);
      if (res.ok) {
        toast.success(res.message);
        setOpen(false);
        setReason("");
      } else toast.error(res.error);
    });
  }

  if (isBlocked) {
    return (
      <Button variant="outline" onClick={() => submit(false)} disabled={isPending}>
        {isPending ? <Loader2Icon className="animate-spin" /> : <ShieldCheckIcon />} Unblock
      </Button>
    );
  }
  return (
    <>
      <Button variant="destructive" onClick={() => setOpen(true)}>
        <BanIcon /> Block
      </Button>
      <Dialog open={isOpen} onOpenChange={setOpen}>
        <DialogContent>
          <form
            className="grid gap-4"
            onSubmit={(e) => {
              e.preventDefault();
              if (isReasonValid) submit(true);
            }}
          >
            <DialogHeader>
              <DialogTitle>Block {name}?</DialogTitle>
              <DialogDescription>
                Blocking signs the user out everywhere and stops new bookings or rides until you unblock them.
              </DialogDescription>
            </DialogHeader>
            <div className="grid gap-2">
              <Label htmlFor="block-reason">Reason</Label>
              <Textarea
                id="block-reason"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder="e.g. Repeated no-shows reported by drivers"
                rows={3}
                maxLength={200}
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
                {isPending ? <Loader2Icon className="animate-spin" /> : <BanIcon />} Block user
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </>
  );
}
