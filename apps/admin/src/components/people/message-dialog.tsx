"use client";

import { Loader2Icon, SendIcon } from "lucide-react";
import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import type { MessageApp } from "@/lib/types";

import { sendMessage } from "@/app/(panel)/actions";

/** A push to one person's phone (POST /admin/users/:id/message), from the admins. */
export function MessageDialog({
  userId,
  driverId,
  name,
  isOpen,
  onOpenChange,
  defaultApp,
  defaultTitle = "",
  defaultBody = "",
}: {
  userId: string;
  driverId?: string;
  name: string;
  isOpen: boolean;
  onOpenChange: (open: boolean) => void;
  /** Driver app for drivers, the rider app otherwise. */
  defaultApp: MessageApp;
  defaultTitle?: string;
  defaultBody?: string;
}) {
  const [title, setTitle] = useState(defaultTitle);
  const [body, setBody] = useState(defaultBody);
  const [app, setApp] = useState<MessageApp>(defaultApp);
  const [isPending, startTransition] = useTransition();
  const isValid = title.trim().length >= 3 && title.trim().length <= 65 && body.trim().length >= 3 && body.trim().length <= 240;

  return (
    <Dialog open={isOpen} onOpenChange={onOpenChange}>
      <DialogContent>
        <form
          className="grid gap-4"
          onSubmit={(e) => {
            e.preventDefault();
            if (!isValid) return;
            startTransition(async () => {
              const res = await sendMessage(userId, { title, body, app }, driverId);
              if (res.ok) {
                toast.success(res.message);
                onOpenChange(false);
              } else toast.error(res.error);
            });
          }}
        >
          <DialogHeader>
            <DialogTitle>Send {name} a push</DialogTitle>
            <DialogDescription>It shows as a notification from Tamil Taxi and is kept in their history here.</DialogDescription>
          </DialogHeader>
          <div className="grid gap-2">
            <Label htmlFor="msg-app">App</Label>
            <Select value={app} onValueChange={(v) => setApp(v as MessageApp)}>
              <SelectTrigger id="msg-app" className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="DRIVER">Driver app</SelectItem>
                <SelectItem value="PASSENGER">Rider app</SelectItem>
                <SelectItem value="BOTH">Both apps</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="msg-title">Title</Label>
            <Input id="msg-title" value={title} onChange={(e) => setTitle(e.target.value)} maxLength={65} placeholder="e.g. Please re-upload your RC" autoFocus />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="msg-body">Message</Label>
            <Textarea
              id="msg-body"
              value={body}
              onChange={(e) => setBody(e.target.value)}
              maxLength={240}
              rows={3}
              placeholder="e.g. The photo was blurred. Open Account › Documents and take it again in good light."
            />
            <p className="text-xs text-muted-foreground">{body.trim().length}/240</p>
          </div>
          <DialogFooter>
            <DialogClose asChild>
              <Button type="button" variant="outline">
                Cancel
              </Button>
            </DialogClose>
            <Button type="submit" disabled={!isValid || isPending}>
              {isPending ? <Loader2Icon className="animate-spin" /> : <SendIcon />} Send push
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/** A button that opens [MessageDialog] (e.g. "Remind" on the Approvals queue). */
export function MessageButton({
  label = "Send push",
  ...props
}: Omit<React.ComponentProps<typeof MessageDialog>, "isOpen" | "onOpenChange"> & { label?: string }) {
  const [isOpen, setOpen] = useState(false);
  return (
    <>
      <Button size="sm" variant="outline" onClick={() => setOpen(true)}>
        <SendIcon /> {label}
      </Button>
      {isOpen && <MessageDialog {...props} isOpen={isOpen} onOpenChange={setOpen} />}
    </>
  );
}
