import type { Metadata, Viewport } from "next";
import { Inter, Poppins } from "next/font/google";

import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { openGraphBase, site } from "@/lib/site";

import "./globals.css";

const inter = Inter({ variable: "--font-inter", subsets: ["latin"] });
const poppins = Poppins({ variable: "--font-poppins", subsets: ["latin"], weight: ["500", "600", "700"] });

const description =
  "Book bike, auto and cab rides or send parcels across Coimbatore. 0% commission and no subscription: " +
  "drivers keep the whole fare.";

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: { default: "Tamil Taxi: 0% commission rides and parcels in Coimbatore", template: "%s · Tamil Taxi" },
  description,
  // No url / description here: pages would inherit the home page's. Next fills og:title from each title; each page
  // sets its own og:url (openGraphBase).
  openGraph: openGraphBase,
  twitter: { card: "summary_large_image" },
};

export const viewport: Viewport = { themeColor: "#ffffff" };

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en-IN" className={`${inter.variable} ${poppins.variable} antialiased`}>
      <body className="flex min-h-screen flex-col font-sans">
        <a
          href="#main"
          className="sr-only focus:not-sr-only focus:fixed focus:top-3 focus:left-3 focus:z-50 focus:rounded-lg focus:bg-white focus:px-4 focus:py-2"
        >
          Skip to content
        </a>
        <SiteHeader />
        <main id="main" className="flex-1">
          {children}
        </main>
        <SiteFooter />
      </body>
    </html>
  );
}
