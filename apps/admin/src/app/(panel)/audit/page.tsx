import { ScrollTextIcon } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";

import { ListFilters } from "@/components/common/list-filters";
import { EmptyState, PageHeader } from "@/components/common/page";
import { Pager } from "@/components/common/pager";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { adminApi } from "@/lib/api";
import { formatCount, formatDate, formatTime, humanize, shortId } from "@/lib/format";
import { param, parsePage } from "@/lib/paging";

export const metadata: Metadata = { title: "Audit log" };

/** Entities recorded by apps/api/src/modules/admin/audit.interceptor.ts (first path segment after /admin). */
const ENTITIES = ["drivers", "users", "cities", "zones", "plans", "tickets", "announcements", "settings"];

/** Where an audited entity id can be opened in this panel. */
function entityHref(entity: string, id: string | null): string | null {
  if (!id) return null;
  const routes: Record<string, string> = { drivers: "/drivers", users: "/users", cities: "/cities" };
  return routes[entity] ? `${routes[entity]}/${id}` : null;
}

const METHOD_TONE: Record<string, string> = {
  POST: "bg-success-tint text-success-text",
  PUT: "bg-coral-50 text-coral-700",
  PATCH: "bg-warning-tint text-warning-text",
  DELETE: "bg-error-tint text-error",
};

export default async function AuditPage({ searchParams }: PageProps<"/audit">) {
  const sp = await searchParams;
  const query = { kind: param(sp.kind), q: param(sp.q) };
  const page = parsePage(sp.page);
  const data = await adminApi.audit({ ...query, page, pageSize: 50 });

  return (
    <>
      <PageHeader title="Audit log" description={`${formatCount(data.total)} admin changes, newest first. Every POST, PUT, PATCH and DELETE is recorded.`} />
      <ListFilters
        searchPlaceholder="Action contains… (e.g. PATCH)"
        filters={[{ name: "kind", label: "Entities", options: ENTITIES.map((e) => ({ value: e, label: humanize(e) })) }]}
      />
      <Card className="gap-0 py-0">
        {data.items.length === 0 ? (
          <EmptyState icon={ScrollTextIcon} title="No audit entries" description="Changes made in the admin panel appear here." />
        ) : (
          <Table>
            <TableHeader>
              <TableRow className="bg-muted/40 hover:bg-muted/40">
                <TableHead className="pl-4">Time</TableHead>
                <TableHead>Actor</TableHead>
                <TableHead>Action</TableHead>
                <TableHead>Entity</TableHead>
                <TableHead className="pr-4">Details</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.items.map((a) => {
                const [method, ...rest] = a.action.split(" ");
                const href = entityHref(a.entity, a.entityId);
                return (
                  <TableRow key={a.id} className="align-top">
                    <TableCell className="pl-4 whitespace-nowrap text-navy-700">
                      {formatDate(a.createdAt)}
                      <span className="block text-xs text-muted-foreground">{formatTime(a.createdAt)}</span>
                    </TableCell>
                    <TableCell>
                      <Link href={`/users/${a.actorId}`} className="font-mono text-xs text-coral-600 hover:underline">
                        {shortId(a.actorId)}
                      </Link>
                    </TableCell>
                    <TableCell>
                      <span className="flex flex-wrap items-center gap-1.5">
                        <Badge variant="secondary" className={METHOD_TONE[method] ?? ""}>
                          {method}
                        </Badge>
                        <span className="font-mono text-xs text-navy-700">{rest.join(" ").replace(/^\/v1/, "")}</span>
                      </span>
                    </TableCell>
                    <TableCell>
                      <span className="block text-sm text-navy-900">{humanize(a.entity)}</span>
                      {a.entityId &&
                        (href ? (
                          <Link href={href} className="font-mono text-xs text-coral-600 hover:underline">
                            {a.entityId.length > 16 ? shortId(a.entityId) : a.entityId}
                          </Link>
                        ) : (
                          <span className="font-mono text-xs text-muted-foreground">{a.entityId.length > 16 ? shortId(a.entityId) : a.entityId}</span>
                        ))}
                    </TableCell>
                    <TableCell className="pr-4">
                      {a.data ? (
                        <details className="group max-w-md">
                          <summary className="cursor-pointer text-xs font-medium text-coral-600 select-none">Show JSON</summary>
                          <pre className="mt-2 max-h-64 overflow-auto rounded-md bg-muted p-2 font-mono text-[11px] whitespace-pre-wrap text-navy-700">
                            {JSON.stringify(a.data, null, 2)}
                          </pre>
                        </details>
                      ) : (
                        <span className="text-muted-foreground">–</span>
                      )}
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        )}
        <Pager path="/audit" query={query} page={data.page} pageSize={data.pageSize} total={data.total} noun="entries" />
      </Card>
    </>
  );
}
