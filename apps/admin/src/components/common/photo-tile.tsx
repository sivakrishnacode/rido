import { ImageIcon } from "lucide-react";

import { docFileHref } from "@/lib/files";
import { cn } from "@/lib/utils";

/** A stored photo (opened through the admin's /files proxy, full size in a new tab), or an empty square. */
export function PhotoTile({ label, file, note, className }: { label: string; file?: string | null; note: string; className?: string }) {
  return (
    <figure className={cn("w-36", className)}>
      {file ? (
        <a href={docFileHref(file)} target="_blank" rel="noreferrer noopener">
          {/* eslint-disable-next-line @next/next/no-img-element -- private, token-proxied file; next/image can't optimise it */}
          <img src={docFileHref(file)} alt={label} className="size-36 rounded-xl border object-cover" />
        </a>
      ) : (
        <div className="flex size-36 items-center justify-center rounded-xl border border-dashed text-xs text-muted-foreground">
          No photo
        </div>
      )}
      <figcaption className="mt-1.5">
        <span className="block text-xs font-medium text-navy-900">{label}</span>
        <span className="block text-xs text-muted-foreground">{note}</span>
      </figcaption>
    </figure>
  );
}

/** A small thumbnail of a ticket's photo that opens it full size (tables, lists). */
export function AttachmentThumb({ file, label = "Photo attached" }: { file: string; label?: string }) {
  return (
    <a
      href={docFileHref(file)}
      target="_blank"
      rel="noreferrer noopener"
      className="mt-1.5 inline-flex items-center gap-2 rounded-lg border p-1 pr-2.5 text-xs font-medium text-navy-700 hover:border-coral-500/40 hover:text-coral-600"
    >
      {/* eslint-disable-next-line @next/next/no-img-element -- private, token-proxied file; next/image can't optimise it */}
      <img src={docFileHref(file)} alt="" className="size-9 rounded-md object-cover" />
      <ImageIcon className="size-3.5" aria-hidden /> {label}
    </a>
  );
}
