// Tests for bright-api Edge Function
//
// Run: deno test supabase/functions/bright-api/index_test.ts
// Requires: Deno 1.x+

import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  findBestCategoryMatch,
  estimateBudget,
  VALID_CATEGORIES,
} from "../_shared/utils.ts";
import { handler } from "./index.ts";

// ─── Helpers ──────────────────────────────────────────────────────────

function mockEnv(overrides: Record<string, string>) {
  const originalEnvGet = Deno.env.get;
  Deno.env.get = (key: string) =>
    overrides[key] ?? originalEnvGet.call(Deno.env, key);
  return () => { Deno.env.get = originalEnvGet; };
}

// ─── Utility Tests (existing) ─────────────────────────────────────────

Deno.test("findBestCategoryMatch", async (t) => {
  await t.step("exact match (case-insensitive)", () => {
    assertEquals(findBestCategoryMatch("Plumbing"), "Plumbing");
    assertEquals(findBestCategoryMatch("plumbing"), "Plumbing");
  });

  await t.step("returns General Labor for no match", () => {
    assertEquals(findBestCategoryMatch("xyz123"), "General Labor");
  });

  await t.step("handles empty string input", () => {
    assertEquals(findBestCategoryMatch(""), "General Labor");
  });
});

Deno.test("estimateBudget", async (t) => {
  await t.step("extracts numeric value from text", () => {
    assertEquals(estimateBudget("Plumbing", "budget 5000"), 5000);
  });

  await t.step("returns category default when no numeric hint", () => {
    assertEquals(estimateBudget("Plumbing", "fix the pipe"), 3000);
    assertEquals(estimateBudget("Electrical", "wire the room"), 3500);
  });

  await t.step("handles k suffix", () => {
    assertEquals(estimateBudget("Plumbing", "budget 5k for plumbing work"), 5000);
  });
});

// ─── Handler Tests ────────────────────────────────────────────────────

Deno.test("handler — returns 401 when Authorization header is missing (BUG #12 regression)", async () => {
  const restoreEnv = mockEnv({});

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      body: JSON.stringify({ description: "fix the sink" }),
    });

    const res = await handler(req);
    assertEquals(res.status, 401);

    const body = await res.json();
    assertEquals(body.error, "Unauthorized — no auth token provided");
  } finally {
    restoreEnv();
  }
});

Deno.test("handler — returns 405 for non-POST methods", async () => {
  const restoreEnv = mockEnv({});

  try {
    const req = new Request("http://localhost", {
      method: "GET",
      headers: { Authorization: "Bearer token" },
    });

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
      headers: {
        Authorization: "Bearer token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ description: "ab" }),
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
  const restoreEnv = mockEnv({
    OPENROUTER_API_KEY: "test-key",
  });

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    // Simulate OpenRouter being unavailable
    return new Response("Service Unavailable", { status: 503 });
  };

  try {
    const req = new Request("http://localhost", {
      method: "POST",
      headers: {
        Authorization: "Bearer token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ description: "Need plumbing for a leaking pipe urgently" }),
    });

    const res = await handler(req);
    assertEquals(res.status, 200);

    const body = await res.json();
    // Falls back to keyword parsing
    assertEquals(body.category, "Plumbing");
    assertEquals(body.urgency, "instant");
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnv();
  }
});

Deno.test("handler — succeeds with valid request and OpenRouter", async () => {
  const restoreEnv = mockEnv({
    OPENROUTER_API_KEY: "test-key",
  });

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    return new Response(
      JSON.stringify({
        choices: [{
          message: {
            content: JSON.stringify({
              category: "Electrical",
              urgency: "today",
              suggested_budget_pkr: 3500,
              estimated_duration_hours: 3,
              required_skills: ["Electrical", "Wiring"],
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
      headers: {
        Authorization: "Bearer token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ description: "Need electrician for home wiring" }),
    });

    const res = await handler(req);
    assertEquals(res.status, 200);

    const body = await res.json();
    assertEquals(body.category, "Electrical");
    assertEquals(body.urgency, "today");
    assertEquals(body.suggested_budget_pkr, 3500);
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnv();
  }
});

Deno.test("handler — validates urgency field", async () => {
  const restoreEnv = mockEnv({ OPENROUTER_API_KEY: "test-key" });

  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    return new Response(
      JSON.stringify({
        choices: [{
          message: {
            content: JSON.stringify({
              category: "Cleaning",
              urgency: "INVALID_URGENCY",
              suggested_budget_pkr: 1500,
              estimated_duration_hours: 2,
              required_skills: [],
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
      headers: {
        Authorization: "Bearer token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ description: "Clean my house" }),
    });

    const res = await handler(req);
    const body = await res.json();

    // Invalid urgency should default to "today"
    assertEquals(body.urgency, "today");
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnv();
  }
});
