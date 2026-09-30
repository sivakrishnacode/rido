import Image from "next/image";

/** An app screenshot (docs/design frames, 560×1212 WebP in public/screens) in a simple phone outline. */
export function Phone({ src, alt, className = "", eager }: { src: string; alt: string; className?: string; eager?: boolean }) {
  return (
    <div className={`rounded-[2.25rem] bg-navy-900 p-2 shadow-2xl shadow-navy-900/20 ${className}`}>
      <Image
        src={src}
        alt={alt}
        width={560}
        height={1212}
        loading={eager ? "eager" : "lazy"}
        className="h-auto w-full rounded-[1.75rem] bg-white"
      />
    </div>
  );
}
