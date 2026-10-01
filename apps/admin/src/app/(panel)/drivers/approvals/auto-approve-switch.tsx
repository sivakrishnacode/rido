"use client";

import { Loader2Icon } from "lucide-react";
import { useTransition } from "react";
import { toast } from "sonner";

import { Switch } from "@/components/ui/switch";

import { setAutoApprove } from "../../actions";

/** Settings › driverAutoApprove, right where the queue is. */
export function AutoApproveSwitch({ isOn }: { isOn: boolean }) {
  const [isPending, startTransition] = useTransition();
  return (
    <label className="flex items-center gap-3 rounded-lg border bg-card px-3 py-2">
      <span className="text-sm">
        <span className="block font-medium text-navy-900">Auto-approve</span>
        <span className="block text-xs text-muted-foreground">{isOn ? "Approved once every check passes" : "Off: you approve each driver"}</span>
      </span>
      {isPending ? (
        <Loader2Icon className="size-4 animate-spin text-muted-foreground" aria-label="Saving" />
      ) : (
        <Switch
          checked={isOn}
          aria-label="Auto-approve drivers"
          onCheckedChange={(v) =>
            startTransition(async () => {
              const res = await setAutoApprove(v);
              if (res.ok) toast.success(res.message);
              else toast.error(res.error);
            })
          }
        />
      )}
    </label>
  );
}
