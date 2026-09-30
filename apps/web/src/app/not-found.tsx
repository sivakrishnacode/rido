import Link from "next/link";

export default function NotFound() {
  return (
    <div className="mx-auto max-w-xl px-4 py-24 text-center sm:px-6">
      <p className="font-heading text-5xl font-semibold text-coral-600">404</p>
      <h1 className="mt-4 font-heading text-2xl font-semibold">This page took a wrong turn</h1>
      <p className="mt-2 text-navy-500">The page you&apos;re looking for doesn&apos;t exist.</p>
      <Link
        href="/"
        className="mt-8 inline-block rounded-full bg-coral-600 px-5 py-2.5 font-semibold text-white hover:bg-coral-700"
      >
        Back to home
      </Link>
    </div>
  );
}
