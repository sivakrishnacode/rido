import {
  BadgeIndianRupeeIcon,
  ClipboardCheckIcon,
  FlameIcon,
  GaugeIcon,
  HexagonIcon,
  IdCardIcon,
  LayoutDashboardIcon,
  LifeBuoyIcon,
  MegaphoneIcon,
  RadarIcon,
  ReceiptIndianRupeeIcon,
  RouteIcon,
  ScrollTextIcon,
  SettingsIcon,
  ShieldAlertIcon,
  UserCheckIcon,
  UserCogIcon,
  UsersIcon,
  WalletCardsIcon,
  type LucideIcon,
} from "lucide-react";

export interface NavItem {
  readonly href: string;
  readonly label: string;
  readonly icon: LucideIcon;
  /** Top-bar search hint when this list page is open (pages that support ?q). */
  readonly searchHint?: string;
}

export interface NavGroup {
  readonly label: string;
  readonly items: readonly NavItem[];
}

export const NAV_GROUPS: readonly NavGroup[] = [
  {
    label: "Overview",
    items: [
      { href: "/", label: "Dashboard", icon: LayoutDashboardIcon },
      { href: "/live", label: "Live", icon: RadarIcon },
      { href: "/heatmap", label: "Heatmap", icon: FlameIcon },
    ],
  },
  {
    label: "Operations",
    items: [
      { href: "/trips", label: "Trips", icon: RouteIcon, searchHint: "Search trips by id, pickup or drop" },
      { href: "/drivers", label: "Drivers", icon: IdCardIcon, searchHint: "Search drivers by name, phone or plate" },
      { href: "/drivers/approvals", label: "Approvals", icon: UserCheckIcon, searchHint: "Search approvals by name, phone or plate" },
      { href: "/kyc", label: "KYC", icon: ClipboardCheckIcon },
      { href: "/passengers", label: "Passengers", icon: UsersIcon, searchHint: "Search passengers by name or phone" },
      { href: "/users", label: "Users", icon: UserCogIcon, searchHint: "Search all accounts by name, phone or email" },
      { href: "/safety", label: "SOS", icon: ShieldAlertIcon },
      { href: "/support", label: "Support", icon: LifeBuoyIcon },
    ],
  },
  {
    label: "Configuration",
    items: [
      { href: "/cities", label: "Zones", icon: HexagonIcon },
      { href: "/plans", label: "Plans", icon: BadgeIndianRupeeIcon },
      { href: "/settings", label: "Settings", icon: SettingsIcon },
      { href: "/announcements", label: "Announcements", icon: MegaphoneIcon },
    ],
  },
  {
    label: "Finance",
    items: [
      { href: "/payments", label: "Payments", icon: WalletCardsIcon },
      { href: "/cancellation-fees", label: "Cancellation fees", icon: ReceiptIndianRupeeIcon },
    ],
  },
  {
    label: "System",
    items: [
      { href: "/travel-speeds", label: "Travel speeds", icon: GaugeIcon },
      { href: "/audit", label: "Audit", icon: ScrollTextIcon, searchHint: "Search audit log by action" },
    ],
  },
];

export const NAV: readonly NavItem[] = NAV_GROUPS.flatMap((g) => g.items);

/** The nav item a path belongs to, the longest match winning ("/drivers/abc" → Drivers, "/drivers/approvals" → Approvals). */
export function activeNav(pathname: string): NavItem {
  const matches = NAV.filter((n) => (n.href === "/" ? pathname === "/" : pathname === n.href || pathname.startsWith(`${n.href}/`)));
  return matches.reduce<NavItem | undefined>((best, n) => (!best || n.href.length > best.href.length ? n : best), undefined) ?? NAV[0];
}

/** Default target of the top-bar search when the open page has no search. */
export const DEFAULT_SEARCH: NavItem = NAV.find((n) => n.href === "/drivers")!;
