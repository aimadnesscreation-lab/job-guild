// Tests for rapid-worker Edge Function
//
// Run: deno test supabase/functions/rapid-worker/index_test.ts
// Requires: Deno 1.x+

import {
  assertEquals,
} from "https://deno.land/std@0.177.0/testing/asserts.ts";

import { VALID_CATEGORIES, findBestCategoryMatch } from "../_shared/utils.ts";

interface ProfileResponse {
  bio: string;
  categories: string[];
}

const CATEGORY_LIMIT = 3;

/**
 * Extract JSON from LLM response, stripping markdown fences.
 */
function extractJson(raw: string): ProfileResponse {
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

  const suggestedCategories = Array.isArray(parsed.categories)
    ? (parsed.categories as unknown[]).map(c => String(c))
    : [];

  return {
    bio: (parsed.bio as string) || "",
    categories: suggestedCategories
      .map(c => findBestCategoryMatch(c))
      .filter((c, index, self) => 
        (VALID_CATEGORIES as unknown as string[]).includes(c) && self.indexOf(c) === index
      )
      .slice(0, CATEGORY_LIMIT),
  };
}

/**
 * Keyword-based fallback when AI is unavailable.
 */
function fallbackParse(text: string): ProfileResponse {
  const lower = text.toLowerCase();
  const matched: string[] = [];
  const keywordMap: Record<string, string> = {
    "plumb": "Plumbing",
    "electr": "Electrical",
    "paint": "Painting",
    "carpent": "Carpentry",
    "mason": "Masonry",
    "mechanic": "Mechanic",
    "bike": "Bike Repair",
    "car wash": "Car Wash",
    "labor": "General Labor",
    "weld": "Welding",
    "steel": "Steel Fixing",
    "tutor": "Tutor",
    "teach": "Language Teacher",
    "laptop": "Laptop Repair",
    "mobile": "Mobile Repair",
    "web": "Web Developer",
    "photo": "Photographer",
    "dj": "DJ",
    "cook": "Cook",
    "clean": "Cleaning",
    "move": "Moving",
    "health": "Healthcare",
    "beauty": "Beauty",
    "pet": "Pet Care",
  };

  for (const [keyword, category] of Object.entries(keywordMap)) {
    if (lower.includes(keyword) && !matched.includes(category)) {
      if (matched.length < CATEGORY_LIMIT) matched.push(category);
    }
  }

  const bio = `Professional with experience in ${matched.join(", ") || "various services"}. ` +
    "Dedicated to providing high-quality service with attention to detail and customer satisfaction. " +
    "Available for projects of all sizes. Reliable, hardworking, and committed to getting the job done right.";

  return {
    bio,
    categories: matched.length > 0 ? matched : ["General Labor"],
  };
}

// ─── Tests ─────────────────────────────────────────────────────────────

Deno.test("extractJson - clean JSON", () => {
  const raw = JSON.stringify({
    bio: "Experienced plumber for 5 years.",
    categories: ["Plumbing"],
  });
  const result = extractJson(raw);
  assertEquals(result.bio, "Experienced plumber for 5 years.");
  assertEquals(result.categories, ["Plumbing"]);
});

Deno.test("extractJson - with markdown fences", () => {
  const raw = "```json\n{\"bio\": \"Expert electrician.\", \"categories\": [\"Electrical\"]}\n```";
  const result = extractJson(raw);
  assertEquals(result.categories, ["Electrical"]);
});

Deno.test("extractJson - unsafe categories type (Bug #5)", () => {
  const raw = JSON.stringify({
    bio: "Test bio",
    categories: "Plumbing", // String instead of Array
  });
  const result = extractJson(raw);
  assertEquals(result.categories, []); // Should not crash, returns empty or fallback logic in index.ts handles it
});

Deno.test("extractJson - unique and limited categories", () => {
  const raw = JSON.stringify({
    bio: "Multi-talented",
    categories: ["Plumbing", "Plumbing", "Electrical", "Painting", "Carpentry"],
  });
  const result = extractJson(raw);
  assertEquals(result.categories.length, 3);
  assertEquals(result.categories, ["Plumbing", "Electrical", "Painting"]);
});

Deno.test("fallbackParse - basic keywords", () => {
  const result = fallbackParse("I do plumbing and electrical work");
  assertEquals(result.categories.includes("Plumbing"), true);
  assertEquals(result.categories.includes("Electrical"), true);
});
