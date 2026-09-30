import Link from "next/link";
import type { ReactNode } from "react";

import type { LegalDoc } from "@/lib/legal";

/** A readable single column for the privacy policy, terms and account deletion pages. */
export function LegalShell({ title, updated, intro, children }: { title: string; updated?: string; intro: string; children: ReactNode }) {
  return (
    <article className="mx-auto max-w-2xl px-4 py-14 sm:px-6 sm:py-20">
      <h1 className="font-heading text-3xl font-semibold tracking-tight sm:text-4xl">{title}</h1>
      {updated ? <p className="mt-2 text-sm text-navy-500">Last updated {updated}</p> : null}
      <p className="mt-6 text-lg text-navy-700">{intro}</p>
      <div className="mt-10 space-y-10">{children}</div>
    </article>
  );
}

export function LegalBlock({ heading, children }: { heading: string; children: ReactNode }) {
  return (
    <section className="space-y-3 text-navy-700">
      <h2 className="font-heading text-xl font-semibold text-navy-900">{heading}</h2>
      {children}
    </section>
  );
}

export function Bullets({ items }: { items: readonly string[] }) {
  return (
    <ul className="list-disc space-y-1.5 pl-5 marker:text-navy-300">
      {items.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ul>
  );
}

export function LegalPage({ doc }: { doc: LegalDoc }) {
  return (
    <LegalShell title={doc.title} updated={doc.updated} intro={doc.intro}>
      {doc.sections.map((s) => (
        <LegalBlock key={s.heading} heading={s.heading}>
          {s.paragraphs.map((p) => (
            <p key={p}>{p}</p>
          ))}
          {s.list ? <Bullets items={s.list} /> : null}
          {s.link ? (
            <p>
              <Link href={s.link.href} className="font-semibold text-coral-600 hover:text-coral-700">
                {s.link.label}
              </Link>
            </p>
          ) : null}
        </LegalBlock>
      ))}
    </LegalShell>
  );
}
