import { Card } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

export default function PlansLoading() {
  return (
    <div aria-busy="true" aria-label="Loading plans">
      <div className="mb-6 space-y-2">
        <Skeleton className="h-7 w-32" />
        <Skeleton className="h-4 w-80" />
      </div>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 8 }, (_, i) => (
          <Card key={i} className="gap-3 px-4">
            <Skeleton className="h-5 w-24" />
            {Array.from({ length: 3 }, (_, j) => (
              <Skeleton key={j} className="h-10 w-full" />
            ))}
          </Card>
        ))}
      </div>
    </div>
  );
}
