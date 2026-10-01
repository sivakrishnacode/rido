import { LinkTabs } from "@/components/common/link-tabs";

/** Switch between a driver's driver page and their account page (one person, two views). */
export function PersonTabs({ userId, driverId, active }: { userId: string; driverId: string; active: "driver" | "account" }) {
  return (
    <LinkTabs
      active={active}
      tabs={[
        { value: "driver", label: "Driver profile", href: `/drivers/${driverId}` },
        { value: "account", label: "Account & rides as rider", href: `/users/${userId}` },
      ]}
    />
  );
}
