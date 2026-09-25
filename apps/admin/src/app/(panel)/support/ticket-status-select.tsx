"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { humanize } from "@/lib/format";
import { TICKET_STATUSES, type TicketStatus } from "@/lib/types";
import { cn } from "@/lib/utils";

import { setTicketStatus } from "../actions";

const TONE: Record<TicketStatus, string> = {
  OPEN: "bg-warning-tint text-warning-text border-transparent",
  IN_PROGRESS: "bg-coral-50 text-coral-700 border-transparent",
  RESOLVED: "bg-success-tint text-success-text border-transparent",
};

/** OPEN / IN_PROGRESS / RESOLVED → PATCH /admin/tickets/:id. */
export function TicketStatusSelect({ ticketId, status }: { ticketId: string; status: TicketStatus }) {
  const [value, setValue] = useState(status);
  const [isPending, startTransition] = useTransition();

  return (
    <Select
      value={value}
      disabled={isPending}
      onValueChange={(next) => {
        const prev = value;
        setValue(next as TicketStatus);
        startTransition(async () => {
          const res = await setTicketStatus(ticketId, next as TicketStatus);
          if (res.ok) toast.success(`Ticket marked ${humanize(next).toLowerCase()}`);
          else {
            setValue(prev);
            toast.error(res.error);
          }
        });
      }}
    >
      <SelectTrigger size="sm" className={cn("relative z-10 w-36 font-medium", TONE[value])} aria-label="Ticket status">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {TICKET_STATUSES.map((s) => (
          <SelectItem key={s} value={s}>
            {humanize(s)}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
