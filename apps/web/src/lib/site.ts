import type { Metadata } from "next";

/** Everything the pages link to, in one place. The repo is public: nothing private goes here. */
export const site = {
  name: "Tamil Taxi",
  /**
   * The website's own domain (registration pending). Live trip share links don't use it: they are
   * SHARE_BASE_URL/track/<token> on the admin app (the API's ShareService).
   */
  url: "https://tamiltaxi.co.in",
  email: "support@tamiltaxi.co.in",
  github: "https://github.com/sivakrishnacode/tamiltaxi",
  city: "Coimbatore",
  /** Set to true once both apps are live on Google Play; until then the buttons say "Coming soon". */
  onPlayStore: false,
  apps: {
    rider: { name: "Tamil Taxi", packageId: "com.tamiltaxi.passenger" },
    driver: { name: "Tamil Taxi Driver", packageId: "com.tamiltaxi.driver" },
  },
} as const;

/**
 * Open Graph tags every page shares. A page's own `openGraph` replaces the layout's (no deep merge), so each page
 * spreads this and adds its `url`. Next copies the image to twitter:image too. The image (public/og-image.png,
 * 1200×630) is the home hero: headline, the rider app's ride choice and a driver request.
 */
export const openGraphBase = {
  type: "website",
  siteName: site.name,
  locale: "en_IN",
  images: [
    {
      url: "/og-image.png",
      width: 1200,
      height: 630,
      alt:
        `${site.name}: rides and parcels across ${site.city} with 0% commission. The rider app choosing a ride, ` +
        "and the driver app showing a ₹38 request that is 100% the driver's.",
    },
  ],
} satisfies NonNullable<Metadata["openGraph"]>;

/** Every page, for the sitemap (a test checks each one exists). */
export const pages = ["/", "/privacy/", "/terms/", "/delete-account/"] as const;

export type AppKey = keyof typeof site.apps;

export function playStoreUrl(app: AppKey): string {
  return `https://play.google.com/store/apps/details?id=${site.apps[app].packageId}`;
}
