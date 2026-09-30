/** Everything the pages link to, in one place. The repo is public: nothing private goes here. */
export const site = {
  name: "Tamil Taxi",
  /** The domain the apps already use for trip share links (tamiltaxi.co.in/t/…). */
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

/** Every page, for the sitemap (a test checks each one exists). */
export const pages = ["/", "/privacy/", "/terms/", "/delete-account/"] as const;

export type AppKey = keyof typeof site.apps;

export function playStoreUrl(app: AppKey): string {
  return `https://play.google.com/store/apps/details?id=${site.apps[app].packageId}`;
}
