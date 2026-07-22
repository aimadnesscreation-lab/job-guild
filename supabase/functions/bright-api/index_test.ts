// Tests for bright-api Edge Function
//
// Run: deno test supabase/functions/bright-api/index_test.ts
// Requires: Deno 1.x+

import {
  assertEquals,
  assertObjectMatch,
} from "https://deno.land/std@0.177.0/testing/asserts.ts";

// ─── Pure functions under test (mirrors production code) ──────────────

interface ParseResponse {
  category: string;
  urgency: string;
  suggested_budget_pkr: number;
  estimated_duration_hours: number;
  required_skills: string[];
}

const VALID_CATEGORIES = [
  "Plumbing", "Electrical", "Painting", "Carpentry", "Masonry",
  "Mechanic", "Bike Repair", "Car Wash",
  "Labor", "Welding", "Steel Fixing",
  "Tutor", "Language Teacher",
  "Laptop Repair", "Mobile Repair", "Web Developer",
  "Photographer", "DJ", "Cook",
  "Cleaning", "Moving", "Healthcare", "Beauty", "Pet Care",
  "General Labor",
] as const;

const VALID_URGENCIES = ["instant", "today", "scheduled"] as const;

/**
 * Find the best matching valid category from the LLM output.
 * Handles case differences and partial matches.
 */
function findBestMatch(input: string, validOptions: string[]): string {
  const lower = input.toLowerCase().trim();
  if (lower.length === 0) return "General Labor";
  const exact = validOptions.find((o) => o.toLowerCase() === lower);
  if (exact) return exact;
  const partial = validOptions.find(
    (o) => o.toLowerCase().includes(lower) || lower.includes(o.toLowerCase()),
  );
  if (partial) return partial;
  return "General Labor";
}

/**
 * Fallback keyword-based parsing when AI is unavailable.
 */
function fallbackParse(text: string): ParseResponse {
  const lower = text.toLowerCase();
  let category = "General Labor";

  if (lower.includes("plumb")) category = "Plumbing";
  else if (lower.includes("electr")) category = "Electrical";
  else if (lower.includes("paint")) category = "Painting";
  else if (lower.includes("carpent")) category = "Carpentry";
  else if (lower.includes("mason") || lower.includes("brick")) category = "Masonry";
  else if (lower.includes("mechanic") || lower.includes("car")) category = "Mechanic";
  else if (lower.includes("bike") || lower.includes("motor")) category = "Bike Repair";
  else if (lower.includes("car wash")) category = "Car Wash";
  else if (lower.includes("welding") || lower.includes("weld")) category = "Welding";
  else if (lower.includes("steel")) category = "Steel Fixing";
  else if (lower.includes("tutor") || lower.includes("teach")) category = "Tutor";
  else if (lower.includes("laptop") || lower.includes("computer")) category = "Laptop Repair";
  else if (lower.includes("mobile") || lower.includes("phone")) category = "Mobile Repair";
  else if (lower.includes("web") || lower.includes("website")) category = "Web Developer";
  else if (lower.includes("photo")) category = "Photographer";
  else if (lower.includes("dj") || lower.includes("music")) category = "DJ";
  else if (lower.includes("cook") || lower.includes("food") || lower.includes("chef")) category = "Cook";
  else if (lower.includes("clean")) category = "Cleaning";
  else if (lower.includes("move") || lower.includes("shift") || lower.includes("relocat")) category = "Moving";
  else if (lower.includes("health") || lower.includes("nurse") || lower.includes("doctor")) category = "Healthcare";
  else if (lower.includes("beauty") || lower.includes("salon") || lower.includes("hair")) category = "Beauty";
  else if (lower.includes("pet") || lower.includes("dog") || lower.includes("cat")) category = "Pet Care";

  const urgency = lower.includes("urgent") || lower.includes("emergency") || lower.includes("asap")
    ? "instant"
    : lower.includes("tomorrow") || lower.includes("next week") || lower.includes("schedule")
      ? "scheduled"
      : "today";

  return {
    category,
    urgency,
    suggested_budget_pkr: estimateBudget(category, lower),
    estimated_duration_hours: lower.includes("hour") || lower.includes("hr")
      ? 1
      : lower.includes("day")
        ? 8
        : 2,
    required_skills: [category],
  };
}

/**
 * Estimate a reasonable budget based on category and any budget hints in text.
 */
function estimateBudget(category: string, text: string): number {
  const match = text.match(/(\d+)\s*(k|rs|pkr)?/i);
  if (match) {
    const num = parseInt(match[1], 10);
    if (match[2]?.toLowerCase() === "k") return num * 1000;
    if (num >= 100 && num <= 100000) return num;
  }
  const budgets: Record<string, number> = {
    Plumbing: 3000, Electrical: 3500, Painting: 4000,
    Carpentry: 3500, Masonry: 5000,
    Mechanic: 3000, "Bike Repair": 1500, "Car Wash": 1000,
    Labor: 2000, Welding: 4000, "Steel Fixing": 5000,
    Tutor: 500, "Language Teacher": 800,
    "Laptop Repair": 2500, "Mobile Repair": 1500, "Web Developer": 5000,
    Photographer: 5000, DJ: 8000, Cook: 3000,
    Cleaning: 1500, Moving: 5000, Healthcare: 2000,
    Beauty: 1500, "Pet Care": 1000,
  };
  return budgets[category] || 2000;
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

  const category = findBestMatch(
    (parsed.category as string) || "",
    VALID_CATEGORIES as unknown as string[],
  );
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

// ─── Tests: findBestMatch ─────────────────────────────────────────────

Deno.test("findBestMatch", async (t) => {
  const options = [...VALID_CATEGORIES] as string[];

  await t.step("exact match (case-insensitive)", () => {
    assertEquals(findBestMatch("Plumbing", options), "Plumbing");
    assertEquals(findBestMatch("plumbing", options), "Plumbing");
    assertEquals(findBestMatch("PLUMBING", options), "Plumbing");
  });

  await t.step("partial match uses input as substring", () => {
    assertEquals(findBestMatch("Plum", options), "Plumbing");
  });

  await t.step("partial match uses option as substring", () => {
    assertEquals(findBestMatch("General", options), "General Labor");
  });

  await t.step("returns General Labor for no match", () => {
    assertEquals(findBestMatch("xyz123_nonexistent", options), "General Labor");
  });

  await t.step("handles empty string input", () => {
    assertEquals(findBestMatch("", options), "General Labor");
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
});

// ─── Tests: fallbackParse ─────────────────────────────────────────────

Deno.test("fallbackParse", async (t) => {
  await t.step("infers Plumbing category", () => {
    const result = fallbackParse("I need a plumber to fix my pipe");
    assertEquals(result.category, "Plumbing");
    assertEquals(result.urgency, "today");
    assertEquals(result.required_skills, ["Plumbing"]);
  });

  await t.step("infers Electrical category", () => {
    const result = fallbackParse("electrical wiring needed");
    assertEquals(result.category, "Electrical");
  });

  await t.step("infers Painting category", () => {
    const result = fallbackParse("paint my bedroom");
    assertEquals(result.category, "Painting");
  });

  await t.step("infers Carpentry category", () => {
    const result = fallbackParse("carpentry work for shelves");
    assertEquals(result.category, "Carpentry");
  });

  await t.step("infers Masonry from brick keyword", () => {
    const result = fallbackParse("brick work for wall");
    assertEquals(result.category, "Masonry");
  });

  await t.step("infers Tutor from teach keyword", () => {
    const result = fallbackParse("teach me mathematics");
    assertEquals(result.category, "Tutor");
  });

  await t.step("defaults to General Labor for unknown input", () => {
    const result = fallbackParse("random task");
    assertEquals(result.category, "General Labor");
  });

  await t.step("detects instant urgency", () => {
    const result = fallbackParse("urgent plumbing repair");
    assertEquals(result.urgency, "instant");
    assertEquals(result.suggested_budget_pkr, 3000);
  });

  await t.step("detects emergency urgency as instant", () => {
    const result = fallbackParse("emergency electrical fix");
    assertEquals(result.urgency, "instant");
  });

  await t.step("detects scheduled urgency from tomorrow keyword", () => {
    const result = fallbackParse("schedule plumbing for tomorrow");
    assertEquals(result.urgency, "scheduled");
  });

  await t.step("estimates 1 hour for hour mention", () => {
    const result = fallbackParse("1 hour plumbing work");
    assertEquals(result.estimated_duration_hours, 1);
  });

  await t.step("estimates 8 hours for day mention", () => {
    const result = fallbackParse("full day painting job");
    assertEquals(result.estimated_duration_hours, 8);
  });

  await t.step("defaults to 2 hours for unspecified duration", () => {
    const result = fallbackParse("fix leaking pipe");
    assertEquals(result.estimated_duration_hours, 2);
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

  await t.step("strips markdown code fences", () => {
    const raw = "```json\n{\"category\": \"Electrical\", \"urgency\": \"today\", \"suggested_budget_pkr\": 3500, \"estimated_duration_hours\": 3, \"required_skills\": [\"Electrical\"]}\n```";
    const result = extractJson(raw);
    assertEquals(result.category, "Electrical");
    assertEquals(result.urgency, "today");
  });

  await t.step("strips markdown fences without json tag", () => {
    const raw = "```\n{\"category\": \"Cleaning\", \"urgency\": \"today\", \"suggested_budget_pkr\": 1500, \"estimated_duration_hours\": 2, \"required_skills\": [\"Cleaning\"]}\n```";
    const result = extractJson(raw);
    assertEquals(result.category, "Cleaning");
  });

  await t.step("extracts JSON object from text with extra content", () => {
    const raw = "Here is the result: {\"category\": \"Painting\", \"urgency\": \"scheduled\", \"suggested_budget_pkr\": 4000, \"estimated_duration_hours\": 4, \"required_skills\": [\"Painting\"]} Hope this helps!";
    const result = extractJson(raw);
    assertEquals(result.category, "Painting");
  });

  await t.step("falls back to keyword parsing on invalid JSON", () => {
    const result = extractJson("This is not JSON at all. I need plumbing work.");
    assertEquals(result.category, "Plumbing");
    assertEquals(result.urgency, "today");
  });

  await t.step("clamps budget to minimum 0", () => {
    const raw = JSON.stringify({
      category: "Plumbing",
      urgency: "today",
      suggested_budget_pkr: -100,
      estimated_duration_hours: 2,
      required_skills: [],
    });
    const result = extractJson(raw);
    assertEquals(result.suggested_budget_pkr, 0);
  });

  await t.step("clamps duration between 1 and 40", () => {
    const raw = JSON.stringify({
      category: "Plumbing",
      urgency: "today",
      suggested_budget_pkr: 1000,
      estimated_duration_hours: 100,
      required_skills: [],
    });
    const result = extractJson(raw);
    assertEquals(result.estimated_duration_hours, 40);

    const raw2 = JSON.stringify({
      category: "Plumbing",
      urgency: "today",
      suggested_budget_pkr: 1000,
      estimated_duration_hours: 0,
      required_skills: [],
    });
    const result2 = extractJson(raw2);
    assertEquals(result2.estimated_duration_hours, 1);
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

  await t.step("defaults urgency to today when invalid", () => {
    const raw = JSON.stringify({
      category: "Plumbing",
      urgency: "invalid_urgency_value",
      suggested_budget_pkr: 1000,
      estimated_duration_hours: 2,
      required_skills: ["Plumbing"],
    });
    const result = extractJson(raw);
    assertEquals(result.urgency, "today");
  });
});
