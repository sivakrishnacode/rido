import type { Metadata } from "next";

import { LegalPage } from "@/components/legal-page";
import { privacy } from "@/lib/legal";

export const metadata: Metadata = {
  title: "Privacy policy",
  description: "What the Tamil Taxi apps collect, why, who sees it and how to delete it.",
  alternates: { canonical: "/privacy/" },
};

export default function PrivacyPage() {
  return <LegalPage doc={privacy} />;
}
