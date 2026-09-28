"use client";

import { Loader2Icon, PlayIcon } from "lucide-react";
import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";

import { liftDriverBlock } from "../../actions";

/** "Lift pause" → POST /admin/drivers/:id/lift-block (audit logged). */
export function LiftBlockButton({ driverId }: { driverId: string }) {
  const [isPending, startTransition] = useTransition();
  return (
    <Button
      size="sm"
      variant="outline"
      disabled={isPending}
      onClick={() =>
        startTransition(async () => {
          const res = await liftDriverBlock(driverId);
          if (res.ok) toast.success(res.message);
          else toast.error(res.error);
        })
      }
    >
      {isPending ? <Loader2Icon className="animate-spin" /> : <PlayIcon />} Lift pause
    </Button>
  );
}
