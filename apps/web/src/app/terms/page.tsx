import type { Metadata } from "next";

import { LegalPage } from "@/components/legal-page";
import { terms } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Terms of service",
  description: "The terms for riders, senders and drivers using Tamil Taxi.",
  alternates: { canonical: "/terms/" },
};

export default function TermsPage() {
  return <LegalPage doc={terms} />;
}
