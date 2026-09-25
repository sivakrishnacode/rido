import {
  BadgeIndianRupeeIcon,
  ClipboardCheckIcon,
  HexagonIcon,
  IdCardIcon,
  LayoutDashboardIcon,
  LifeBuoyIcon,
  MegaphoneIcon,
  RadarIcon,
  RouteIcon,
  ScrollTextIcon,
  SettingsIcon,
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
    ],
  },
  {
    label: "Operations",
    items: [
      { href: "/trips", label: "Trips", icon: RouteIcon, searchHint: "Search trips by id, pickup or drop" },
      { href: "/drivers", label: "Drivers", icon: IdCardIcon, searchHint: "Search drivers by name, phone or plate" },
      { href: "/kyc", label: "KYC", icon: ClipboardCheckIcon },
      { href: "/passengers", label: "Passengers", icon: UsersIcon, searchHint: "Search passengers by name or phone" },
      { href: "/users", label: "Users", icon: UserCogIcon, searchHint: "Search all accounts by name, phone or email" },
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
  { label: "Finance", items: [{ href: "/payments", label: "Payments", icon: WalletCardsIcon }] },
  { label: "System", items: [{ href: "/audit", label: "Audit", icon: ScrollTextIcon, searchHint: "Search audit log by action" }] },
];

export const NAV: readonly NavItem[] = NAV_GROUPS.flatMap((g) => g.items);

/** The nav item a path belongs to ("/drivers/abc" → Drivers). */
export function activeNav(pathname: string): NavItem {
  return (
    NAV.find((n) => (n.href === "/" ? pathname === "/" : pathname === n.href || pathname.startsWith(`${n.href}/`))) ?? NAV[0]
  );
}

/** Default target of the top-bar search when the open page has no search. */
export const DEFAULT_SEARCH: NavItem = NAV.find((n) => n.href === "/drivers")!;
