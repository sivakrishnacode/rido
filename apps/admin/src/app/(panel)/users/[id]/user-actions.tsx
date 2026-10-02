"use client";

import { Loader2Icon } from "lucide-react";
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
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { humanize } from "@/lib/format";
import { ROLES, type Role } from "@/lib/types";

import { setUserRole } from "../../actions";

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
                ? "Admins can sign in to this panel and change anything here, from their next sign-in. Note: phones in ADMIN_PHONES always sign in as admin."
                : `The new role applies from the user's next sign-in${role === "ADMIN" ? ": until then they keep admin access" : ""}. A driver role still needs a driver profile to take rides.`}
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
