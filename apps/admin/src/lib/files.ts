/** Link for a KYC document or photo: uploaded files go through the admin-only `/files/:name` proxy; full URLs open as they are. */
export function docFileHref(fileUrl: string): string {
  return /^https?:\/\//.test(fileUrl) ? fileUrl : `/files/${encodeURIComponent(fileUrl)}`;
}
