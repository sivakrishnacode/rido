"use client";

import { Bar, BarChart, CartesianGrid, LabelList, XAxis, YAxis } from "recharts";

import { ChartContainer, ChartTooltip, ChartTooltipContent, type ChartConfig } from "@/components/ui/chart";
import { formatDayLabel } from "@/lib/format";

const config = { count: { label: "Trips", color: "var(--chart-1)" } } satisfies ChartConfig;

/** Trips per day for the last 7 days (GET /admin/stats → tripsLast7Days). */
export function TripsChart({ data }: { data: { date: string; count: number }[] }) {
  const rows = data.map((d) => ({ ...d, label: formatDayLabel(d.date) }));
  return (
    <ChartContainer config={config} className="aspect-auto h-64 w-full">
      <BarChart data={rows} margin={{ top: 20, left: -20, right: 8 }} accessibilityLayer>
        <CartesianGrid vertical={false} />
        <XAxis dataKey="label" tickLine={false} axisLine={false} tickMargin={8} />
        <YAxis allowDecimals={false} tickLine={false} axisLine={false} width={40} />
        <ChartTooltip cursor={false} content={<ChartTooltipContent hideIndicator />} />
        <Bar dataKey="count" fill="var(--color-count)" radius={[6, 6, 0, 0]} maxBarSize={48}>
          <LabelList dataKey="count" position="top" className="fill-navy-700" fontSize={12} />
        </Bar>
      </BarChart>
    </ChartContainer>
  );
}
