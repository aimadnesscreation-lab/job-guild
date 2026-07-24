// Tests for send-push-notification Edge Function
//
// Run: deno test supabase/functions/send-push-notification/index_test.ts
// Requires: Deno 1.x+

import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { encodeBase64Url } from "../_shared/utils.ts";
import { handler } from "./index.ts";

// ─── Helpers ──────────────────────────────────────────────────────────

function mockEnv(overrides: Record<string, string>) {
  const originalEnvGet = Deno.env.get;
  Deno.env.get = (key: string) =>
    overrides[key] ?? originalEnvGet.call(Deno.env, key);
  return () => { Deno.env.get = originalEnvGet; };
}

// ─── Pure Function Tests ──────────────────────────────────────────────

Deno.test("pemToBinary", async (t) => {
  // pemToBinary is defined inside index.ts and not exported — covered via
  // handler tests below.  Pure encodeBase64Url is tested via shared utils.
  await t.step("encodeBase64Url basic", () => {
    const result = encodeBase64Url("test");
    assertEquals(result.includes("+"), false);
    assertEquals(result.includes("/"), false);
    assertEquals(result.includes("="), false);
  });
});

// ─── Handler Tests ────────────────────────────────────────────────────

Deno.test("handler — returns 405 for non-POST methods", async () => {
  const restoreEnv = mockEnv({});

  try {
    const req = new Request("http://localhost", { method: "GET" });
    const res = await handler(req);
    assertEquals(res.status, 405);
  } finally {
    restoreEnv();
  }
});

Deno.test("handler — returns 400 when user_id is missing", async () => {
  const restoreEnv = mockEnv({});

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: "Test", body: "Hello" }),
    });

    const res = await handler(req);
    assertEquals(res.status, 400);

    const body = await res.json();
    assertEquals(body.error, "user_id and title are required");
  } finally {
    restoreEnv();
  }
});

Deno.test("handler — returns 400 when title is missing", async () => {
  const restoreEnv = mockEnv({});

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ user_id: "user-1", body: "Hello" }),
    });

    const res = await handler(req);
    assertEquals(res.status, 400);
  } finally {
    restoreEnv();
  }
});

Deno.test("handler — returns error when no FCM token found", async () => {
  const restoreEnv = mockEnv({
    SUPABASE_URL: "https://test.supabase.co",
    SUPABASE_SERVICE_ROLE_KEY: "test-key",
  });

  // Mock Supabase RPC returning 404 (no token)
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input: RequestInfo | URL) => {
    const url = input.toString();
    if (url.includes("rpc/get_user_fcm_token")) {
      return new Response(JSON.stringify(null), { status: 200 });
    }
    if (url.includes("fcm_tokens")) {
      // Fallback query returns empty
      return new Response(JSON.stringify([]), { status: 200 });
    }
    return new Response("Not Found", { status: 404 });
  };

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        user_id: "user-1",
        title: "Test notification",
        body: "Hello",
      }),
    });

    const res = await handler(req);
    const body = await res.json();

    assertEquals(body.success, false);
    assertEquals(body.error, "No FCM token found");
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnv();
  }
});

Deno.test("handler — sends notification successfully (mocked chain)", async () => {
  const restoreEnv = mockEnv({
    SUPABASE_URL: "https://test.supabase.co",
    SUPABASE_SERVICE_ROLE_KEY: "test-key",
    FCM_SERVICE_ACCOUNT: JSON.stringify({
      project_id: "test-project",
      private_key:
        "-----BEGIN PRIVATE KEY-----\nMIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg\n-----END PRIVATE KEY-----",
      client_email: "test@test-project.iam.gserviceaccount.com",
    }),
  });

  // Mock crypto.subtle — the dummy test key won't import as a real key
  const origImportKey = crypto.subtle.importKey;
  const origSign = crypto.subtle.sign;
  crypto.subtle.importKey = async () => ({}) as CryptoKey;
  crypto.subtle.sign = async () => new Uint8Array(64).buffer;

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input: RequestInfo | URL) => {
    const url = input.toString();

    // 1. Supabase RPC — returns FCM token
    if (url.includes("rpc/get_user_fcm_token")) {
      return new Response(
        JSON.stringify("fake-device-token-abc123"),
        { status: 200 },
      );
    }

    // 2. Supabase REST (fallback) — not reached since RPC succeeds
    if (url.includes("fcm_tokens") && url.includes("user_id")) {
      return new Response(JSON.stringify([]), { status: 200 });
    }

    // 3. Google OAuth2 token endpoint
    if (url.includes("oauth2.googleapis.com/token")) {
      return new Response(
        JSON.stringify({ access_token: "test-oauth-token", expires_in: 3600 }),
        { status: 200 },
      );
    }

    // 4. FCM send
    if (url.includes("fcm.googleapis.com")) {
      return new Response(
        JSON.stringify({ name: "projects/test/messages/abc123" }),
        { status: 200 },
      );
    }

    return new Response("Not Found", { status: 404 });
  };

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        user_id: "user-1",
        title: "New message",
        body: "You have a new message from Ali",
        data: { type: "new_message", id: "job-1" },
      }),
    });

    const res = await handler(req);
    const body = await res.json();

    assertEquals(res.status, 200);
    assertEquals(body.success, true);
    assertExists(body.message_id);
  } finally {
    globalThis.fetch = originalFetch;
    crypto.subtle.importKey = origImportKey;
    crypto.subtle.sign = origSign;
    restoreEnv();
  }
});

Deno.test("handler — handles UNREGISTERED token by removing it", async () => {
  const restoreEnv = mockEnv({
    SUPABASE_URL: "https://test.supabase.co",
    SUPABASE_SERVICE_ROLE_KEY: "test-key",
    FCM_SERVICE_ACCOUNT: JSON.stringify({
      project_id: "test-project",
      private_key:
        "-----BEGIN PRIVATE KEY-----\nMIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg\n-----END PRIVATE KEY-----",
      client_email: "test@test-project.iam.gserviceaccount.com",
    }),
  });

  // Mock crypto.subtle — dummy key won't import
  const origImportKey2 = crypto.subtle.importKey;
  const origSign2 = crypto.subtle.sign;
  crypto.subtle.importKey = async () => ({}) as CryptoKey;
  crypto.subtle.sign = async () => new Uint8Array(64).buffer;

  let deleteCalled = false;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = input.toString();
    const method = (init?.method as string) || "GET";

    if (url.includes("rpc/get_user_fcm_token")) {
      return new Response(JSON.stringify("dead-token"), { status: 200 });
    }

    if (url.includes("oauth2.googleapis.com/token")) {
      return new Response(
        JSON.stringify({ access_token: "test-token", expires_in: 3600 }),
        { status: 200 },
      );
    }

    if (url.includes("fcm.googleapis.com")) {
      return new Response(
        JSON.stringify({
          error: { message: "UNREGISTERED", status: "NOT_FOUND" },
        }),
        { status: 404 },
      );
    }

    // BUG #13 regression: dead token should be deleted
    if (method === "DELETE" && url.includes("fcm_tokens")) {
      deleteCalled = true;
      return new Response("", { status: 200 });
    }

    return new Response("Not Found", { status: 404 });
  };

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        user_id: "user-1",
        title: "Test",
        body: "Hello",
      }),
    });

    const res = await handler(req);
    const body = await res.json();

    assertEquals(body.success, false);
    assertEquals(body.error, "UNREGISTERED");
    assertEquals(deleteCalled, true, "Dead token must be deleted from DB");
  } finally {
    globalThis.fetch = originalFetch;
    crypto.subtle.importKey = origImportKey2;
    crypto.subtle.sign = origSign2;
    restoreEnv();
  }
});
