"use server";

import { redirect } from "next/navigation";

import { ApiError, authApi } from "./api";
import { safeNext } from "./api-core";
import { clearSession, setSession } from "./session";

export type AuthResult = { ok: true; expiresInSeconds?: number } | { ok: false; error: string };

const PHONE = /^[6-9]\d{9}$/;
const OTP = /^\d{6}$/;

/** Step 1: ask the API to send an OTP to +91 <phone>. */
export async function sendOtp(phone: string): Promise<AuthResult> {
  if (!PHONE.test(phone)) return { ok: false, error: "Enter a valid 10-digit mobile number" };
  try {
    const res = await authApi.sendOtp(phone);
    return { ok: true, expiresInSeconds: res.expiresInSeconds };
  } catch (e) {
    if (e instanceof ApiError) return { ok: false, error: e.message };
    throw e;
  }
}

/** Step 2: verify the OTP; only ADMIN accounts get a session cookie. */
export async function verifyOtp(phone: string, code: string, next?: string): Promise<AuthResult> {
  if (!PHONE.test(phone)) return { ok: false, error: "Enter a valid 10-digit mobile number" };
  if (!OTP.test(code)) return { ok: false, error: "Enter the 6-digit OTP" };
  try {
    const res = await authApi.verify(phone, code);
    if (res.user.role !== "ADMIN") return { ok: false, error: "This number is not an admin" };
    await setSession(res.accessToken, res.user);
  } catch (e) {
    if (e instanceof ApiError) return { ok: false, error: e.message };
    throw e;
  }
  redirect(safeNext(next));
}

export async function logout(): Promise<void> {
  await clearSession();
  redirect("/login");
}
