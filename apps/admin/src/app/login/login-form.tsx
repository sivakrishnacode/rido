"use client";

import { ArrowLeftIcon, Loader2Icon } from "lucide-react";
import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { InputOTP, InputOTPGroup, InputOTPSlot } from "@/components/ui/input-otp";
import { Label } from "@/components/ui/label";
import { sendOtp, verifyOtp } from "@/lib/auth-actions";

const PHONE = /^[6-9]\d{9}$/;

export function LoginForm({ next }: { next?: string }) {
  const [step, setStep] = useState<"phone" | "otp">("phone");
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const isPhoneValid = PHONE.test(phone);

  function requestOtp(e?: React.FormEvent) {
    e?.preventDefault();
    if (!isPhoneValid) {
      setError("Enter a valid 10-digit mobile number");
      return;
    }
    setError(null);
    startTransition(async () => {
      const res = await sendOtp(phone);
      if (!res.ok) {
        setError(res.error);
        return;
      }
      setStep("otp");
      setCode("");
      toast.success(`OTP sent to +91 ${phone}`);
    });
  }

  function submitOtp(value = code) {
    if (value.length !== 6) {
      setError("Enter the 6-digit OTP");
      return;
    }
    setError(null);
    startTransition(async () => {
      // On success the action redirects, so a result only comes back on failure.
      const res = await verifyOtp(phone, value, next);
      if (!res.ok) {
        setError(res.error);
        setCode("");
      }
    });
  }

  if (step === "phone") {
    return (
      <form onSubmit={requestOtp} className="space-y-4" noValidate>
        <div className="space-y-2">
          <Label htmlFor="phone">Mobile number</Label>
          <div className="flex h-11 items-center rounded-lg border border-input bg-card focus-within:border-ring focus-within:ring-3 focus-within:ring-ring/30">
            <span className="border-r px-3 text-sm font-medium text-navy-700">+91</span>
            <Input
              id="phone"
              name="phone"
              inputMode="numeric"
              autoComplete="tel-national"
              autoFocus
              placeholder="98765 43210"
              maxLength={10}
              value={phone}
              onChange={(e) => setPhone(e.target.value.replace(/\D/g, "").slice(0, 10))}
              aria-invalid={!!error}
              aria-describedby={error ? "login-error" : undefined}
              className="h-full border-0 bg-transparent text-base shadow-none focus-visible:ring-0"
            />
          </div>
        </div>
        {error && (
          <p id="login-error" role="alert" className="text-sm text-error">
            {error}
          </p>
        )}
        <Button type="submit" size="lg" className="h-11 w-full text-sm" disabled={!isPhoneValid || isPending}>
          {isPending && <Loader2Icon className="animate-spin" />}
          Send OTP
        </Button>
      </form>
    );
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        submitOtp();
      }}
      className="space-y-5"
      noValidate
    >
      <div className="space-y-1">
        <button
          type="button"
          onClick={() => {
            setStep("phone");
            setError(null);
          }}
          className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
        >
          <ArrowLeftIcon className="size-4" /> Change number
        </button>
        <p className="text-sm text-navy-700">
          Enter the 6-digit code sent to <span className="font-medium">+91 {phone}</span>
        </p>
      </div>
      <div className="space-y-2">
        <Label htmlFor="otp" className="sr-only">
          OTP
        </Label>
        <InputOTP
          id="otp"
          maxLength={6}
          value={code}
          onChange={(v) => setCode(v.replace(/\D/g, ""))}
          onComplete={(v: string) => submitOtp(v)}
          autoFocus
          disabled={isPending}
          aria-invalid={!!error}
          containerClassName="justify-between"
        >
          <InputOTPGroup className="w-full justify-between gap-2">
            {Array.from({ length: 6 }, (_, i) => (
              <InputOTPSlot
                key={i}
                index={i}
                className="size-12 rounded-lg border bg-card text-lg font-semibold first:rounded-lg last:rounded-lg"
              />
            ))}
          </InputOTPGroup>
        </InputOTP>
      </div>
      {error && (
        <p role="alert" className="text-sm text-error">
          {error}
        </p>
      )}
      <Button type="submit" size="lg" className="h-11 w-full text-sm" disabled={code.length !== 6 || isPending}>
        {isPending && <Loader2Icon className="animate-spin" />}
        Verify and sign in
      </Button>
      <p className="text-center text-sm text-muted-foreground">
        Didn&apos;t get it?{" "}
        <button type="button" onClick={() => requestOtp()} disabled={isPending} className="font-medium text-primary hover:underline">
          Resend OTP
        </button>
      </p>
    </form>
  );
}
