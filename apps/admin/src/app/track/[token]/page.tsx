import type { Metadata } from "next";
import { headers } from "next/headers";

import { Wordmark } from "@/components/common/wordmark";
import { fetchShare, viewerIp } from "@/lib/track-server";

import { TrackView } from "./track-view";

export const metadata: Metadata = {
  title: { absolute: "Live trip · Rido" },
  description: "Follow a Rido trip live.",
  robots: { index: false, follow: false },
};

/**
 * Public live trip page for a share link (no sign-in; outside the admin panel). Server-rendered with the first read,
 * then the browser polls /api/track/<token> every few seconds.
 */
export default async function TrackPage({ params }: PageProps<"/track/[token]">) {
  const { token } = await params;
  const initial = await fetchShare(token, viewerIp(await headers()));
  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-xl flex-col gap-3 bg-background px-4 py-4">
      <header className="flex items-center justify-between">
        <Wordmark />
        <span className="text-xs text-muted-foreground">Live trip</span>
      </header>
      <TrackView token={token} initial={initial} />
      <footer className="pt-2 text-center text-xs text-muted-foreground">
        Shared by a Rido rider. The location stops 30 minutes after the trip ends. In an emergency call 112.
      </footer>
    </main>
  );
}
