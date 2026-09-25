import type { Metadata } from "next";

import { Wordmark } from "@/components/common/wordmark";
import { param } from "@/lib/paging";

import { LoginForm } from "./login-form";

export const metadata: Metadata = { title: "Sign in" };

export default async function LoginPage({ searchParams }: PageProps<"/login">) {
  const sp = await searchParams;
  const isExpired = param(sp.expired) === "1";
  const next = param(sp.next);

  return (
    <main className="grid min-h-screen lg:grid-cols-[1.1fr_1fr]">
      <section className="relative hidden overflow-hidden bg-navy-900 p-12 text-white lg:flex lg:flex-col lg:justify-between">
        <Wordmark tone="white" className="text-4xl" />
        <div className="max-w-md space-y-4">
          <p className="text-sm font-medium tracking-wide text-coral-100 uppercase">Coimbatore · zero commission</p>
          <h1 className="text-3xl leading-tight font-semibold">
            Drivers keep 100% of every fare. You keep the city moving.
          </h1>
          <p className="text-navy-300">
            Review KYC, watch trips live, tune daily, weekly and monthly plans, and close support tickets.
          </p>
        </div>
        <p className="text-xs text-navy-300">Rido admin panel</p>
        <div aria-hidden className="absolute -right-24 -bottom-24 size-80 rounded-full bg-coral-600/20" />
        <div aria-hidden className="absolute -right-8 -bottom-8 size-40 rounded-full bg-coral-500/30" />
      </section>

      <section className="flex items-center justify-center px-4 py-12 sm:px-8">
        <div className="w-full max-w-sm space-y-8">
          <div className="space-y-2">
            <Wordmark className="text-3xl lg:hidden" />
            <h2 className="text-2xl font-semibold text-navy-900">Sign in</h2>
            <p className="text-sm text-muted-foreground">Use the mobile number registered as a Rido admin.</p>
          </div>
          {isExpired && (
            <p role="status" className="rounded-lg bg-warning-tint px-3 py-2 text-sm text-warning-text">
              Your session has ended. Please sign in again.
            </p>
          )}
          <LoginForm next={next} />
        </div>
      </section>
    </main>
  );
}
