import { SearchXIcon } from "lucide-react";
import Link from "next/link";

import { EmptyState } from "@/components/common/page";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";

export default function NotFound() {
  return (
    <Card className="mx-auto mt-6 max-w-lg">
      <EmptyState
        icon={SearchXIcon}
        title="Not found"
        description="This record doesn't exist or was removed."
        action={
          <Button asChild variant="outline">
            <Link href="/">Back to dashboard</Link>
          </Button>
        }
      />
    </Card>
  );
}
