import { UsersIcon } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { ListFilters } from "@/components/common/list-filters";
import { EmptyState, PageHeader } from "@/components/common/page";
import { Pager } from "@/components/common/pager";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { adminApi } from "@/lib/api";
import { formatCount, formatDate, formatPhone, initials } from "@/lib/format";
import { DEFAULT_PAGE_SIZE, param, parsePage } from "@/lib/paging";

export const metadata: Metadata = { title: "Passengers" };

export default async function PassengersPage({ searchParams }: PageProps<"/passengers">) {
  const sp = await searchParams;
  const query = { q: param(sp.q) };
  const page = parsePage(sp.page);
  const data = await adminApi.passengers({ ...query, page, pageSize: DEFAULT_PAGE_SIZE });

  return (
    <>
      <PageHeader title="Passengers" description={`${formatCount(data.total)} ${query.q ? "matching" : "registered"} passengers.`} />
      <ListFilters searchPlaceholder="Name or phone" />
      <Card className="gap-0 py-0">
        {data.items.length === 0 ? (
          <EmptyState
            icon={UsersIcon}
            title={query.q ? "No passengers match" : "No passengers yet"}
            description={query.q ? "Try another name or phone number." : "Passengers appear after their first sign-in."}
          />
        ) : (
          <Table>
            <TableHeader>
              <TableRow className="bg-muted/40 hover:bg-muted/40">
                <TableHead className="pl-4">Passenger</TableHead>
                <TableHead>Phone</TableHead>
                <TableHead>Email</TableHead>
                <TableHead className="text-right">Trips</TableHead>
                <TableHead>Preferences</TableHead>
                <TableHead className="pr-4">Joined</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.items.map((u) => (
                <TableRow key={u.id} className="relative">
                  <TableCell className="pl-4">
                    <Link
                      href={`/users/${u.id}`}
                      className="flex items-center gap-2.5 font-medium text-navy-900 after:absolute after:inset-0 hover:text-coral-600"
                    >
                      <Avatar className="size-8">
                        <AvatarFallback className="bg-coral-50 text-xs font-semibold text-coral-600">{initials(u.name)}</AvatarFallback>
                      </Avatar>
                      {u.name ?? <span className="font-normal text-muted-foreground">No name yet</span>}
                    </Link>
                  </TableCell>
                  <TableCell className="tabular-nums text-navy-700">{formatPhone(u.phone)}</TableCell>
                  <TableCell className="text-navy-700">{u.email ?? "–"}</TableCell>
                  <TableCell className="text-right font-medium tabular-nums">{formatCount(u._count.trips)}</TableCell>
                  <TableCell>
                    <span className="flex flex-wrap gap-1">
                      {u.preferWomenDriver && <Badge variant="outline">Women drivers</Badge>}
                      {u.autoShareTrips && <Badge variant="outline">Auto-share trips</Badge>}
                      {!u.preferWomenDriver && !u.autoShareTrips && <span className="text-xs text-muted-foreground">–</span>}
                    </span>
                  </TableCell>
                  <TableCell className="pr-4 text-navy-700">{formatDate(u.createdAt)}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
        <Pager path="/passengers" query={query} page={data.page} pageSize={data.pageSize} total={data.total} noun="passengers" />
      </Card>
      <p className="mt-3 text-xs text-muted-foreground">
        Open{" "}
        <Link href="/users" className="text-coral-600 hover:underline">
          Users
        </Link>{" "}
        to block accounts or change roles.
      </p>
    </>
  );
}
