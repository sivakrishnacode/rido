import type { Metadata } from "next";
import Link from "next/link";

import { Bullets, LegalBlock, LegalShell } from "@/components/legal-page";
import { deletion } from "@/lib/legal";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Delete your account",
  description: "How to delete your Tamil Taxi or Tamil Taxi Driver account, and what is deleted.",
  alternates: { canonical: "/delete-account/" },
};

const subject = encodeURIComponent("Delete my Tamil Taxi account");
const body = encodeURIComponent("Please delete my account.\n\nMobile number on the account: \nApp (Tamil Taxi / Tamil Taxi Driver): ");

export default function DeleteAccountPage() {
  return (
    <LegalShell
      title="Delete your account"
      intro={`You can delete your ${site.apps.rider.name} or ${site.apps.driver.name} account at any time, with or without the app installed.`}
    >
      <LegalBlock heading="How to ask">
        <ol className="space-y-4">
          <li className="rounded-2xl border border-divider p-5">
            <p className="font-semibold text-navy-900">In the app</p>
            <p className="mt-1">Open Account › Help & support and send &quot;Please delete my account&quot;.</p>
          </li>
          <li className="rounded-2xl border border-divider p-5">
            <p className="font-semibold text-navy-900">By email</p>
            <p className="mt-1">
              Write to{" "}
              <a href={`mailto:${site.email}?subject=${subject}&body=${body}`} className="font-semibold text-coral-600 hover:text-coral-700">
                {site.email}
              </a>{" "}
              with the mobile number on your account and which app you use.
            </p>
          </li>
        </ol>
        <p>
          We confirm the request with you on that number before deleting anything. Deleting an account can&apos;t be
          undone.
        </p>
      </LegalBlock>

      <LegalBlock heading="What we delete">
        <Bullets items={deletion.deleted} />
      </LegalBlock>

      <LegalBlock heading="What we keep">
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
