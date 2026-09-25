// Pure helpers behind the server-only API client (kept separate so they can be unit-tested).
import { withQuery, type QueryInput } from "./paging";
import type { ApiErrorBody } from "./types";

export const DEFAULT_API_URL = "http://localhost:3000/v1";

/** Base URL of the Rido API, without a trailing slash. */
export function apiBaseUrl(env: Record<string, string | undefined> = process.env): string {
  return (env.API_URL?.trim() || DEFAULT_API_URL).replace(/\/+$/, "");
}

/** Joins base + path + query: ("http://x/v1", "/admin/drivers", {page: 2}) → "http://x/v1/admin/drivers?page=2". */
export function apiUrl(base: string, path: string, query?: QueryInput): string {
  const cleanPath = path.startsWith("/") ? path : `/${path}`;
  return withQuery(`${base.replace(/\/+$/, "")}${cleanPath}`, query);
}

/** Error thrown for any non-2xx API response (or when the API cannot be reached). */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

/** Human-readable message from the API's error body ({ message: string | string[] }). */
export function errorMessage(body: unknown, status: number): string {
  const message = (body as Partial<ApiErrorBody> | null)?.message;
  if (Array.isArray(message) && message.length > 0) return message.join(", ");
  if (typeof message === "string" && message.trim()) return message;
  if (status === 404) return "Not found";
  if (status === 401) return "Your session has expired";
  if (status === 403) return "You don't have access to this";
  return `Request failed (${status})`;
}

/** Only same-site relative paths are allowed as a post-login destination. */
export function safeNext(next: string | null | undefined): string {
  if (!next || !next.startsWith("/") || next.startsWith("//") || next.startsWith("/login")) return "/";
  return next;
}
