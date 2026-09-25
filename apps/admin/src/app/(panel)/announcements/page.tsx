import { MegaphoneIcon } from "lucide-react";
import type { Metadata } from "next";

import { EmptyState, PageHeader } from "@/components/common/page";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { adminApi } from "@/lib/api";
import { formatDateTime } from "@/lib/format";

import { AnnouncementToggle, DeleteAnnouncementButton, NewAnnouncementButton } from "./announcement-controls";

export const metadata: Metadata = { title: "Announcements" };

/** True once an optional end date has passed. */
function hasEnded(endsAt: string | null): boolean {
  return !!endsAt && new Date(endsAt).getTime() <= Date.now();
}

const AUDIENCE = { ALL: "Everyone", PASSENGER: "Passengers", DRIVER: "Drivers" } as const;

export default async function AnnouncementsPage() {
  const [items, cities] = await Promise.all([adminApi.announcements(), adminApi.cities()]);
  const cityName = new Map(cities.map((c) => [c.id, c.name]));

  return (
    <>
      <PageHeader
        title="Announcements"
        description="Banners for passengers and drivers: service updates, weather, festivals, new features."
        actions={<NewAnnouncementButton cities={cities.map((c) => ({ id: c.id, name: c.name }))} />}
      />
      {items.length === 0 ? (
        <Card>
          <EmptyState icon={MegaphoneIcon} title="No announcements" description="Create one to show a banner in the apps." />
        </Card>
      ) : (
        <div className="grid gap-3">
          {items.map((a) => {
            const isOver = hasEnded(a.endsAt);
            return (
              <Card key={a.id} className="flex-row items-start gap-4 px-4">
                <span className="mt-0.5 flex size-9 shrink-0 items-center justify-center rounded-lg bg-coral-50 text-coral-600">
                  <MegaphoneIcon className="size-4" aria-hidden />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="flex flex-wrap items-center gap-2 font-heading font-semibold text-navy-900">
                    {a.title}
                    <Badge variant="outline">{AUDIENCE[a.audience]}</Badge>
                    <Badge variant="outline">{a.cityId ? (cityName.get(a.cityId) ?? a.cityId) : "All cities"}</Badge>
                    {isOver ? (
                      <Badge variant="secondary">Ended</Badge>
                    ) : a.isActive ? (
                      <Badge variant="secondary" className="bg-success-tint text-success-text">
                        Live
                      </Badge>
                    ) : (
                      <Badge variant="secondary">Hidden</Badge>
                    )}
                  </p>
                  <p className="mt-1 text-sm whitespace-pre-line text-navy-700">{a.body}</p>
                  <p className="mt-1 text-xs text-muted-foreground">
                    From {formatDateTime(a.startsAt)}
                    {a.endsAt ? ` until ${formatDateTime(a.endsAt)}` : " · no end date"}
                  </p>
                </div>
                <div className="flex shrink-0 items-center gap-2">
                  <AnnouncementToggle id={a.id} isActive={a.isActive} title={a.title} />
                  <DeleteAnnouncementButton id={a.id} title={a.title} />
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </>
  );
}
