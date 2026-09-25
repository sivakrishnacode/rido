import type { Metadata } from "next";

import { PageHeader } from "@/components/common/page";
import { adminApi } from "@/lib/api";

import { SettingsForm } from "./settings-form";

export const metadata: Metadata = { title: "Settings" };

export default async function SettingsPage() {
  const settings = await adminApi.settings();
  return (
    <>
      <PageHeader title="Settings" description="Platform-wide values used by fares, dispatch, plans and the apps. Changes apply within ~15 seconds." />
      <SettingsForm initial={settings} />
    </>
  );
}
