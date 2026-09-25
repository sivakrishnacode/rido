import { Card } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

export default function DetailLoading() {
  return (
    <div aria-busy="true" aria-label="Loading">
      <Skeleton className="mb-3 h-4 w-24" />
      <div className="mb-6 flex items-center gap-4">
        <Skeleton className="size-14 rounded-full" />
        <div className="space-y-2">
          <Skeleton className="h-7 w-56" />
          <Skeleton className="h-4 w-40" />
        </div>
      </div>
      <div className="grid gap-4 lg:grid-cols-3">
        {Array.from({ length: 3 }, (_, i) => (
          <Card key={i} className="gap-3 px-4">
            <Skeleton className="h-5 w-32" />
            {Array.from({ length: 4 }, (_, j) => (
              <Skeleton key={j} className="h-9 w-full" />
            ))}
          </Card>
        ))}
      </div>
    </div>
  );
}
