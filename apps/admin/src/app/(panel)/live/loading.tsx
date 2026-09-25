import { Skeleton } from "@/components/ui/skeleton";

export default function LiveLoading() {
  return (
    <div aria-busy="true" aria-label="Loading live map">
      <div className="mb-6 space-y-2">
        <Skeleton className="h-7 w-24" />
        <Skeleton className="h-4 w-72" />
      </div>
      <div className="grid gap-4 lg:grid-cols-[1fr_340px]">
        <Skeleton className="h-[60vh] rounded-xl" />
        <Skeleton className="h-80 rounded-xl" />
      </div>
    </div>
  );
}
