// Tests for rapid-worker Edge Function
//
// Run: deno test supabase/functions/rapid-worker/index_test.ts
// Requires: Deno 1.x+

import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { VALID_CATEGORIES, findBestCategoryMatch } from "../_shared/utils.ts";
import { handler } from "./index.ts";

// ─── Helpers ──────────────────────────────────────────────────────────

function mockEnv(overrides: Record<string, string>) {
  const originalEnvGet = Deno.env.get;
  Deno.env.get = (key: string) =>
    overrides[key] ?? originalEnvGet.call(Deno.env, key);
  return () => { Deno.env.get = originalEnvGet; };
}

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

Deno.test("handler — returns 400 for short description", async () => {
  const restoreEnv = mockEnv({});

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ raw_description: "ab" }),
    });

    const res = await handler(req);
    assertEquals(res.status, 400);

    const body = await res.json();
    assertEquals(body.error, "Description must be at least 3 characters");
  } finally {
    restoreEnv();
  }
});

Deno.test("handler — uses fallbackParse when OpenRouter fails", async () => {
  const restoreEnv = mockEnv({ OPENROUTER_API_KEY: "test-key" });

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    return new Response("Service Unavailable", { status: 503 });
  };

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        raw_description:
          "I am a plumber with 5 years of experience. I also do electrical work.",
      }),
    });

    const res = await handler(req);
    assertEquals(res.status, 200);

    const body = await res.json();
    // Fallback should find at least Plumbing from keywords
    assertEquals(body.categories.includes("Plumbing"), true);
    assertEquals(typeof body.bio, "string");
    assertEquals(body.bio.length > 0, true);
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnv();
  }
});

Deno.test("handler — succeeds with valid AI response", async () => {
  const restoreEnv = mockEnv({ OPENROUTER_API_KEY: "test-key" });

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    return new Response(
      JSON.stringify({
        choices: [{
          message: {
            content: JSON.stringify({
              bio: "Professional electrician with 10 years of experience.",
              categories: ["Electrical", "Plumbing"],
            }),
          },
        }],
      }),
      { status: 200 },
    );
  };

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        raw_description: "I am an experienced electrician and plumber.",
      }),
    });

    const res = await handler(req);
    assertEquals(res.status, 200);

    const body = await res.json();
    assertEquals(body.bio, "Professional electrician with 10 years of experience.");
    assertEquals(body.categories.length > 0, true);
    assertEquals(body.categories.includes("Electrical"), true);
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnv();
  }
});

Deno.test("handler — deduplicates and limits categories to 3", async () => {
  const restoreEnv = mockEnv({ OPENROUTER_API_KEY: "test-key" });

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    return new Response(
      JSON.stringify({
        choices: [{
          message: {
            content: JSON.stringify({
              bio: "Multi-talented worker.",
              categories: [
                "Plumbing", "Plumbing", "Electrical", "Painting", "Carpentry",
              ],
            }),
          },
        }],
      }),
      { status: 200 },
    );
  };

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ raw_description: "Multi-skilled worker" }),
    });

    const res = await handler(req);
    const body = await res.json();

    assertEquals(body.categories.length <= 3, true);
    // Should be de-duplicated and limited
    const unique = new Set(body.categories);
    assertEquals(unique.size, body.categories.length);
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnv();
  }
});

Deno.test("handler — ensures at least one category from fallback when AI returns none", async () => {
  const restoreEnv = mockEnv({ OPENROUTER_API_KEY: "test-key" });

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    return new Response(
      JSON.stringify({
        choices: [{
          message: {
            content: JSON.stringify({
              bio: "Hardworking professional.",
              categories: [],
            }),
          },
        }],
      }),
      { status: 200 },
    );
  };

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        raw_description: "I do plumbing work",
      }),
    });

    const res = await handler(req);
    const body = await res.json();

    // Even when AI returns empty categories, the fallback should fill in
    assertEquals(body.categories.length > 0, true);
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnv();
  }
});
