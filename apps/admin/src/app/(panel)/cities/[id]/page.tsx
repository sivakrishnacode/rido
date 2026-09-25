import { ArrowLeftIcon } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { PageHeader } from "@/components/common/page";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { adminApi } from "@/lib/api";
import { formatCount } from "@/lib/format";
import { param } from "@/lib/paging";
import { cellsToKm2 } from "@/lib/validation";

import { CitySettings } from "./city-settings";
import { FaresEditor } from "./fares-editor";
import { ServiceAreaEditor } from "./service-area-editor";
import { ZonesEditor } from "./zones-editor";

const TABS = ["area", "zones", "fares", "settings"] as const;

export async function generateMetadata({ params }: PageProps<"/cities/[id]">): Promise<Metadata> {
  const { id } = await params;
  return { title: `Zones · ${id}` };
}

export default async function CityPage({ params, searchParams }: PageProps<"/cities/[id]">) {
  const { id } = await params;
  const sp = await searchParams;
  const tabParam = param(sp.tab);
  const tab = TABS.find((t) => t === tabParam) ?? "area";
  const [city, fares] = await Promise.all([adminApi.city(id), adminApi.fares(id)]);

  return (
    <>
      <Link href="/cities" className="mb-3 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeftIcon className="size-4" /> Cities
      </Link>
      <PageHeader
        title={
          <span className="flex flex-wrap items-center gap-2">
            {city.name}
            {city.isActive ? (
              <Badge className="bg-success-tint text-success-text">Active</Badge>
            ) : (
              <Badge variant="secondary">Inactive</Badge>
            )}
          </span>
        }
        description={`${city.state} · ${formatCount(city.serviceCells.length)} hexagons (≈${formatCount(Math.round(cellsToKm2(city.serviceCells.length, city.h3Resolution)))} km²) · ${city.zones.length} zones`}
      />
      <Tabs defaultValue={tab} className="gap-4">
        <TabsList>
          <TabsTrigger value="area">Service area</TabsTrigger>
          <TabsTrigger value="zones">Zones</TabsTrigger>
          <TabsTrigger value="fares">Fares</TabsTrigger>
          <TabsTrigger value="settings">Settings</TabsTrigger>
        </TabsList>
        <TabsContent value="area">
          <ServiceAreaEditor key={city.updatedAt} city={city} />
        </TabsContent>
        <TabsContent value="zones">
          <ZonesEditor city={city} />
        </TabsContent>
        <TabsContent value="fares">
          <FaresEditor cityId={city.id} fares={fares} />
        </TabsContent>
        <TabsContent value="settings">
          <CitySettings key={city.updatedAt} city={city} />
        </TabsContent>
      </Tabs>
    </>
  );
}
