/** The app-icon mark (same as src/app/icon.svg) and the wordmark. */
export function LogoMark({ className = "size-8" }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" className={className} aria-hidden="true">
      <rect width="64" height="64" rx="14" fill="#F4511E" />
      <g transform="translate(14.00 14.07) scale(0.1401)" fill="#FFFFFF">
        <path d="M76.3 149.2 0 256H74.5L113.5 201.4L76.3 149.2ZM182.9 0 143.9 54.6 181.1 106.8 257.4 0Z M0 0H74.5L257.4 256H182.9Z" />
      </g>
    </svg>
  );
}

export function Logo() {
  return (
    <span className="flex items-center gap-2.5">
      <LogoMark />
      <span className="font-heading text-lg font-semibold tracking-tight">Tamil Taxi</span>
    </span>
  );
}
