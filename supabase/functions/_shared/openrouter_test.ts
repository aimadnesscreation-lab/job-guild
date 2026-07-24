// Tests for shared OpenRouter client
//
// Run: deno test supabase/functions/_shared/openrouter_test.ts
// Requires: Deno 1.x+

import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { callOpenRouter } from "./openrouter.ts";

// ─── Helpers ──────────────────────────────────────────────────────────

function mockEnv(overrides: Record<string, string>) {
  const originalEnvGet = Deno.env.get;
  Deno.env.get = (key: string) => {
    if (key in overrides) return overrides[key];
    return originalEnvGet.call(Deno.env, key);
  };
  return () => { Deno.env.get = originalEnvGet; };
}

function mockFetch(responseInit: ResponseInit & { body?: string }, urlMatch = "") {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = input.toString();
    if (urlMatch && !url.includes(urlMatch)) {
      return new Response("Not Found", { status: 404 });
    }
    return new Response(responseInit.body ?? "{}", {
      status: responseInit.status ?? 200,
      headers: responseInit.headers,
    });
  };
  return () => { globalThis.fetch = originalFetch; };
}

// ─── Tests ────────────────────────────────────────────────────────────

Deno.test("callOpenRouter — throws when API key is missing", async () => {
  const restore = mockEnv({ OPENROUTER_API_KEY: "" });
  try {
    await assertRejects(
      () => callOpenRouter("system", "user"),
      Error,
      "OPENROUTER_API_KEY",
    );
  } finally {
    restore();
  }
});

Deno.test("callOpenRouter — returns content on success", async () => {
  const restoreEnv = mockEnv({ OPENROUTER_API_KEY: "test-key" });
  const restoreFetch = mockFetch({
    status: 200,
    body: JSON.stringify({
      choices: [{ message: { content: "Parsed job JSON here" } }],
    }),
  }, "openrouter.ai");

  try {
    const result = await callOpenRouter("System prompt", "User prompt");
    assertEquals(result, "Parsed job JSON here");
  } finally {
    restoreFetch();
    restoreEnv();
  }
});

Deno.test("callOpenRouter — retries with openrouter/free on 503", async () => {
  const restoreEnv = mockEnv({ OPENROUTER_API_KEY: "test-key" });

  let callCount = 0;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    callCount++;
    const body = init?.body as string | undefined;
    // First call → 503. Second call → 200 with retry model.
    if (callCount === 1) {
      return new Response("Service Unavailable", { status: 503 });
    }
    // Verify the retry used openrouter/free
    if (body && !body.includes("openrouter/free")) {
      throw new Error("Retry did not use openrouter/free model");
    }
    return new Response(
      JSON.stringify({
        choices: [{ message: { content: "Fallback result" } }],
      }),
      { status: 200 },
    );
  };

  try {
    const result = await callOpenRouter("System", "User");
    assertEquals(callCount, 2);
    assertEquals(result, "Fallback result");
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnv();
  }
});

Deno.test("callOpenRouter — retries with openrouter/free on 429", async () => {
  const restoreEnv = mockEnv({ OPENROUTER_API_KEY: "test-key" });

  let callCount = 0;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    callCount++;
    if (callCount === 1) {
      return new Response("Rate limited", { status: 429 });
    }
    return new Response(
      JSON.stringify({
        choices: [{ message: { content: "Retry success" } }],
      }),
      { status: 200 },
    );
  };

  try {
    const result = await callOpenRouter("System", "User");
    assertEquals(callCount, 2);
    assertEquals(result, "Retry success");
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnv();
  }
});

Deno.test("callOpenRouter — does NOT retry on non-retryable status (404)", async () => {
  const restoreEnv = mockEnv({ OPENROUTER_API_KEY: "test-key" });

  let callCount = 0;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    callCount++;
    return new Response("Not Found", { status: 404 });
  };

  try {
    await assertRejects(
      () => callOpenRouter("System", "User"),
      Error,
      "404",
    );
    assertEquals(callCount, 1); // no retry
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnv();
  }
});

Deno.test("callOpenRouter — returns empty string for empty content", async () => {
  const restoreEnv = mockEnv({ OPENROUTER_API_KEY: "test-key" });
  const restoreFetch = mockFetch({
    status: 200,
    body: JSON.stringify({
      choices: [{ message: { content: "" } }],
    }),
  }, "openrouter.ai");

  try {
    const result = await callOpenRouter("System", "User");
    assertEquals(result, "");
  } finally {
    restoreFetch();
    restoreEnv();
  }
});
