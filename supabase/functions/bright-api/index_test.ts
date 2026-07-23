// Tests for bright-api Edge Function
//
// Run: deno test supabase/functions/bright-api/index_test.ts
// Requires: Deno 1.x+

import {
  assertEquals,
} from "https://deno.land/std@0.177.0/testing/asserts.ts";

// Import from shared utils to ensure test/production logic parity (Bug #4)
import { 
  findBestCategoryMatch, 
  estimateBudget, 
  VALID_CATEGORIES 
} from "../_shared/utils.ts";

interface ParseResponse {
  category: string;
  urgency: string;
  suggested_budget_pkr: number;
  estimated_duration_hours: number;
  required_skills: string[];
}

const VALID_URGENCIES = ["instant", "today", "scheduled"] as const;

/**
 * Fallback keyword-based parsing when AI is unavailable.
 */
function fallbackParse(text: string): ParseResponse {
  const lower = text.toLowerCase();
  const category = findBestCategoryMatch(text);

  const urgency = lower.includes("urgent") || lower.includes("emergency") || lower.includes("asap")
    ? "instant"
    : lower.includes("tomorrow") || lower.includes("next week") || lower.includes("schedule")
      ? "scheduled"
      : "today";

  return {
    category,
    urgency,
    suggested_budget_pkr: estimateBudget(category, text),
    estimated_duration_hours: lower.includes("hour") || lower.includes("hr")
      ? 1
      : lower.includes("day")
        ? 8
        : 2,
    required_skills: [category],
  };
}

/**
 * Parse the raw LLM response text into a structured JSON object.
 * Handles cases where the model includes markdown fences or extra text.
 */
function extractJson(raw: string): ParseResponse {
  let cleaned = raw
    .replace(/^```(?:json)?\s*/gm, "")
    .replace(/\s*```$/gm, "")
    .trim();

  const jsonMatch = cleaned.match(/\{[\s\S]*\}/);
  if (jsonMatch) cleaned = jsonMatch[0];

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(cleaned) as Record<string, unknown>;
  } catch {
    return fallbackParse(raw);
  }

  const category = findBestCategoryMatch((parsed.category as string) || "");
  const urgency = (VALID_URGENCIES as readonly string[]).includes(parsed.urgency as string)
    ? (parsed.urgency as string)
    : "today";

  const skills = Array.isArray(parsed.required_skills)
    ? (parsed.required_skills as string[]).map((s) => String(s))
    : [category];

  return {
    category,
    urgency,
    suggested_budget_pkr:
      typeof parsed.suggested_budget_pkr === "number"
        ? Math.max(0, parsed.suggested_budget_pkr)
        : estimateBudget(category, ""),
    estimated_duration_hours:
      typeof parsed.estimated_duration_hours === "number"
        ? Math.max(1, Math.min(40, parsed.estimated_duration_hours))
        : 2,
    required_skills: skills,
  };
}

// ─── Tests: findBestCategoryMatch ──────────────────────────────────────

Deno.test("findBestCategoryMatch", async (t) => {
  await t.step("exact match (case-insensitive)", () => {
    assertEquals(findBestCategoryMatch("Plumbing"), "Plumbing");
    assertEquals(findBestCategoryMatch("plumbing"), "Plumbing");
    assertEquals(findBestCategoryMatch("PLUMBING"), "Plumbing");
  });

  await t.step("partial match uses input as substring", () => {
    assertEquals(findBestCategoryMatch("Plum"), "Plumbing");
  });

  await t.step("partial match uses option as substring", () => {
    assertEquals(findBestCategoryMatch("General"), "General Labor");
  });

  await t.step("returns General Labor for no match", () => {
    assertEquals(findBestCategoryMatch("xyz123_nonexistent"), "General Labor");
  });

  await t.step("handles empty string input", () => {
    assertEquals(findBestCategoryMatch(""), "General Labor");
  });
});

// ─── Tests: estimateBudget ────────────────────────────────────────────

Deno.test("estimateBudget", async (t) => {
  await t.step("extracts numeric value from text", () => {
    assertEquals(estimateBudget("Plumbing", "5000 for the job"), 5000);
  });

  await t.step("handles k suffix (multiply by 1000)", () => {
    assertEquals(estimateBudget("Plumbing", "5k plumbing work"), 5000);
  });

  await t.step("handles K suffix (uppercase)", () => {
    assertEquals(estimateBudget("Cleaning", "2K cleaning"), 2000);
  });

  await t.step("ignores number below 100 (not a budget)", () => {
    assertEquals(estimateBudget("Plumbing", "50 cheap job"), 3000); // category default
  });

  await t.step("ignores number above 100000 (unrealistic)", () => {
    assertEquals(estimateBudget("Painting", "200000 too high"), 4000); // category default
  });

  await t.step("returns category default when no numeric hint", () => {
    assertEquals(estimateBudget("Plumbing", "fix the pipe"), 3000);
    assertEquals(estimateBudget("Electrical", "wire the room"), 3500);
    assertEquals(estimateBudget("Cleaning", "clean house"), 1500);
    assertEquals(estimateBudget("Tutor", "math lessons"), 500);
  });

  await t.step("returns fallback 2000 for unknown categories", () => {
    assertEquals(estimateBudget("Unknown Category", "some work"), 2000);
  });

  await t.step("handles house numbers correctly", () => {
    // Should NOT pick 42 as budget because it's too small and not near a keyword.
    // Should pick 3000 if it can't find anything, but let's test a valid budget next to it.
    assertEquals(estimateBudget("Plumbing", "House 42, budget 5000"), 5000);
  });
});

// ─── Tests: extractJson ──────────────────────────────────────────────

Deno.test("extractJson", async (t) => {
  await t.step("parses clean JSON response", () => {
    const raw = JSON.stringify({
      category: "Plumbing",
      urgency: "instant",
      suggested_budget_pkr: 3000,
      estimated_duration_hours: 2,
      required_skills: ["Plumbing"],
    });
    const result = extractJson(raw);
    assertEquals(result.category, "Plumbing");
    assertEquals(result.urgency, "instant");
    assertEquals(result.suggested_budget_pkr, 3000);
    assertEquals(result.estimated_duration_hours, 2);
    assertEquals(result.required_skills, ["Plumbing"]);
  });

  await t.step("returns empty skills array when required_skills is empty", () => {
    const raw = JSON.stringify({
      category: "Plumbing",
      urgency: "today",
      suggested_budget_pkr: 1000,
      estimated_duration_hours: 2,
      required_skills: [],
    });
    const result = extractJson(raw);
    assertEquals(result.required_skills, []);
  });
});
