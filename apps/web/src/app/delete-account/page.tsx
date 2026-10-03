import type { Metadata } from "next";
import Link from "next/link";

import { Bullets, LegalBlock, LegalShell } from "@/components/legal-page";
import { deletion } from "@/lib/legal";
import { openGraphBase, site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Delete your account",
  description: "How to delete your Tamil Taxi or Tamil Taxi Driver account, and what is deleted.",
  alternates: { canonical: "/delete-account/" },
  openGraph: { ...openGraphBase, url: "/delete-account/" },
};

const subject = encodeURIComponent("Delete my Tamil Taxi account");
const body = encodeURIComponent("Please delete my account.\n\nMobile number on the account: \nApp (Tamil Taxi / Tamil Taxi Driver): ");

export default function DeleteAccountPage() {
  return (
    <LegalShell
      title="Delete your account"
      intro={`You can delete your ${site.apps.rider.name} or ${site.apps.driver.name} account at any time: in the app, or by email if you no longer have it. Drivers' records are kept for 6 months first, for police enquiries.`}
    >
      <LegalBlock heading="How to delete it">
        <ol className="space-y-4">
          <li className="rounded-2xl border border-divider p-5">
            <p className="font-semibold text-navy-900">In the app</p>
            <p className="mt-1">
              {site.apps.rider.name}: open Account › Delete account and confirm. If a trip is still going, finish or
              cancel it first.
            </p>
            <p className="mt-1">
              {site.apps.driver.name}: open Account › Help &amp; support › Delete my account and send the ticket.
            </p>
          </li>
          <li className="rounded-2xl border border-divider p-5">
            <p className="font-semibold text-navy-900">By email</p>
            <p className="mt-1">
              If you can&apos;t use the app, write to{" "}
              <a href={`mailto:${site.email}?subject=${subject}&body=${body}`} className="font-semibold text-coral-600 hover:text-coral-700">
                {site.email}
              </a>{" "}
              with the mobile number on your account and which app you use. We may contact you on that number to
              check that the request is yours before we delete the account.
            </p>
          </li>
        </ol>
        <p>Deleting an account can&apos;t be undone.</p>
      </LegalBlock>

      <LegalBlock heading="What is deleted">
        <Bullets items={deletion.deleted} />
      </LegalBlock>

      <LegalBlock heading="What is kept">
        <Bullets items={deletion.kept} />
        <p>
          See the{" "}
          <Link href="/privacy/" className="font-semibold text-coral-600 hover:text-coral-700">
            privacy policy
          </Link>{" "}
          for everything we collect.
        </p>
      </LegalBlock>
    </LegalShell>
  );
}
