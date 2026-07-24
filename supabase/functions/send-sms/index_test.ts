// Tests for send-sms Edge Function
//
// Run: deno test supabase/functions/send-sms/index_test.ts
// Requires: Deno 1.x+

import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { extractOtpFromMessage } from "../_shared/utils.ts";
import { handler } from "./index.ts";

// ─── Helpers ──────────────────────────────────────────────────────────

function mockEnv(overrides: Record<string, string>) {
  const originalEnvGet = Deno.env.get;
  Deno.env.get = (key: string) =>
    overrides[key] ?? originalEnvGet.call(Deno.env, key);
  return () => { Deno.env.get = originalEnvGet; };
}

function captureLogs(): { entries: string[]; restore: () => void } {
  const entries: string[] = [];
  const originalLog = console.log;
  console.log = (...args: unknown[]) => {
    entries.push(args.map((a) => String(a)).join(" "));
    originalLog(...args);
  };
  return { entries, restore: () => { console.log = originalLog; } };
}

// ─── Utility Tests (existing) ─────────────────────────────────────────

Deno.test("extractOtpFromMessage", async (t) => {
  await t.step("extracts 6-digit code from message", () => {
    assertEquals(extractOtpFromMessage("Your OTP is 123456"), "123456");
  });

  await t.step("extracts code with surrounding punctuation", () => {
    assertEquals(extractOtpFromMessage("Code: 987654. Please verify."), "987654");
  });

  await t.step("returns null when no 6-digit code present", () => {
    assertEquals(extractOtpFromMessage("Your OTP is 12345"), null);
  });

  await t.step("returns null for empty message", () => {
    assertEquals(extractOtpFromMessage(""), null);
  });

  await t.step("extracts first 6-digit code when multiple exist", () => {
    assertEquals(extractOtpFromMessage("First: 111111, Second: 222222"), "111111");
  });

  await t.step("handles codes with spaces inside (should not match)", () => {
    assertEquals(extractOtpFromMessage("Code: 123 456"), null);
  });
});

// ─── Handler Tests ────────────────────────────────────────────────────

Deno.test("handler — log provider (DEV mode does NOT log OTP)", async () => {
  const restoreEnv = mockEnv({
    SMS_PROVIDER: "log",
    ENVIRONMENT: "production",
  });
  const logs = captureLogs();

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      body: JSON.stringify({
        phone: "+923001234567",
        message: "Your code is 123456",
        type: "sms",
      }),
    });

    const res = await handler(req);
    const body = await res.json();

    assertEquals(res.status, 200);
    assertEquals(body.success, true);
    assertEquals(body.message, "[DEV MODE] OTP delivery simulated");

    // Must NOT log the OTP in production
    const otpLogged = logs.entries.some((e) => e.includes("123456"));
    assertEquals(otpLogged, false);
  } finally {
    logs.restore();
    restoreEnv();
  }
});

Deno.test("handler — log provider (DEV mode DOES log OTP)", async () => {
  const restoreEnv = mockEnv({
    SMS_PROVIDER: "log",
    ENVIRONMENT: "development",
  });
  const logs = captureLogs();

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      body: JSON.stringify({
        phone: "+923001234567",
        otp: "654321",
        type: "sms",
      }),
    });

    const res = await handler(req);
    const body = await res.json();

    assertEquals(res.status, 200);
    assertEquals(body.success, true);

    // In dev mode, the OTP SHOULD be logged
    const otpLogged = logs.entries.some((e) => e.includes("654321"));
    assertEquals(otpLogged, true);
  } finally {
    logs.restore();
    restoreEnv();
  }
});

Deno.test("handler — twilio provider uses Messaging API (BUG #2 regression)", async () => {
  const restoreEnv = mockEnv({
    SMS_PROVIDER: "twilio",
    TWILIO_ACCOUNT_SID: "AC123",
    TWILIO_AUTH_TOKEN: "token",
    TWILIO_SERVICE_SID: "SID123",
    TWILIO_PHONE_NUMBER: "+15551234567",
  });

  let capturedUrl = "";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    capturedUrl = input.toString();
    return new Response(JSON.stringify({ sid: "SM123" }), { status: 201 });
  };

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      body: JSON.stringify({
        phone: "+923001234567",
        message: "Your verification code is 987654",
        type: "sms",
      }),
    });

    const res = await handler(req);
    const body = await res.json();

    assertEquals(res.status, 200);
    assertEquals(body.success, true);

    // BUG #2 regression: must use Messaging API, NOT Verify API
    assertEquals(
      capturedUrl.includes("api.twilio.com/2010-04-01/Accounts/AC123/Messages.json"),
      true,
      `Expected Messaging API URL, got: ${capturedUrl}`,
    );
    assertEquals(
      capturedUrl.includes("verify.twilio.com"),
      false,
      "Must NOT use Verify API",
    );
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnv();
  }
});

Deno.test("handler — twilio provider throws when credentials missing", async () => {
  const restoreEnv = mockEnv({
    SMS_PROVIDER: "twilio",
    // Missing TWILIO_ACCOUNT_SID etc.
  });

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      body: JSON.stringify({
        phone: "+923001234567",
        type: "sms",
      }),
    });

    const res = await handler(req);
    const body = await res.json();

    assertEquals(res.status, 500);
    assertEquals(body.success, false);
    assertEquals(body.error, "Twilio credentials not configured");
  } finally {
    restoreEnv();
  }
});

Deno.test("handler — textlocal provider succeeds", async () => {
  const restoreEnv = mockEnv({
    SMS_PROVIDER: "textlocal",
    TEXTLOCAL_API_KEY: "apikey123",
  });

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    return new Response(
      JSON.stringify({ status: "success" }),
      { status: 200 },
    );
  };

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      body: JSON.stringify({
        phone: "+923001234567",
        message: "Your code is 111111",
        type: "sms",
      }),
    });

    const res = await handler(req);
    const body = await res.json();

    assertEquals(res.status, 200);
    assertEquals(body.success, true);
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnv();
  }
});

Deno.test("handler — returns 500 for invalid JSON body", async () => {
  const restoreEnv = mockEnv({ SMS_PROVIDER: "log" });

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      body: "not-valid-json",
    });

    const res = await handler(req);
    assertEquals(res.status, 500);
  } finally {
    restoreEnv();
  }
});

Deno.test("handler — unknown provider returns 400", async () => {
  const restoreEnv = mockEnv({ SMS_PROVIDER: "unknown-vendor" });

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      body: JSON.stringify({ phone: "+92", type: "sms" }),
    });

    const res = await handler(req);
    const body = await res.json();

    assertEquals(res.status, 400);
    assertEquals(body.success, false);
    assertEquals(body.error, "Unknown SMS provider: unknown-vendor");
  } finally {
    restoreEnv();
  }
});
