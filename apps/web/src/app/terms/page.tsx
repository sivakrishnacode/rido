import type { Metadata } from "next";

import { LegalPage } from "@/components/legal-page";
import { terms } from "@/lib/legal";
import { openGraphBase } from "@/lib/site";

export const metadata: Metadata = {
  title: "Terms of service",
  description: "The terms for riders, senders and drivers using Tamil Taxi.",
  alternates: { canonical: "/terms/" },
  openGraph: { ...openGraphBase, url: "/terms/" },
};

export default function TermsPage() {
  return <LegalPage doc={terms} />;
}
