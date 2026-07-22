// Tests for rapid-worker Edge Function
//
// Run: deno test supabase/functions/rapid-worker/index_test.ts
// Requires: Deno 1.x+

import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.177.0/testing/asserts.ts";

// ─── Pure functions under test (mirrors production code) ──────────────

interface ProfileResponse {
  bio: string;
  categories: string[];
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
];

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
      if (matched.length < 3) matched.push(category);
    }
  }

  const bio =
    `Professional with experience in ${matched.join(", ") || "various services"}. ` +
    "Dedicated to providing high-quality service with attention to detail and customer satisfaction. " +
    "Available for projects of all sizes. Reliable, hardworking, and committed to getting the job done right.";

  return {
    bio,
    categories: matched.length > 0 ? matched : ["General Labor"],
  };
}

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

  return {
    bio: (parsed.bio as string) || "",
    categories: (parsed.categories as string[])?.filter((c) =>
      VALID_CATEGORIES.includes(c)
    ) || [],
  };
}

// ─── Tests: fallbackParse ─────────────────────────────────────────────

Deno.test("fallbackParse", async (t) => {
  await t.step("infers single category from keyword", () => {
    const result = fallbackParse("I work as a plumber");
    assertEquals(result.categories, ["Plumbing"]);
    assertStringIncludes(result.bio, "Plumbing");
  });

  await t.step("infers up to 3 categories", () => {
    const result = fallbackParse(
      "I do plumbing, electrical work, and painting",
    );
    assertEquals(result.categories, ["Plumbing", "Electrical", "Painting"]);
    assertStringIncludes(result.bio, "Plumbing, Electrical, Painting");
  });

  await t.step("deduplicates categories", () => {
    const result = fallbackParse("plumber and plumbing expert");
    assertEquals(result.categories, ["Plumbing"]);
  });

  await t.step("defaults to General Labor for unknown input", () => {
    const result = fallbackParse("I do random tasks");
    assertEquals(result.categories, ["General Labor"]);
    assertStringIncludes(result.bio, "various services");
  });

  await t.step("infers Electrical from electr keyword", () => {
    const result = fallbackParse("electrical installation work");
    assertEquals(result.categories, ["Electrical"]);
  });

  await t.step("infers Painting from paint keyword", () => {
    const result = fallbackParse("painting walls and ceilings");
    assertEquals(result.categories, ["Painting"]);
  });

  await t.step("infers Carpentry from carpent keyword", () => {
    const result = fallbackParse("carpentry and woodworking");
    assertEquals(result.categories, ["Carpentry"]);
  });

  await t.step("infers Masonry from mason keyword", () => {
    const result = fallbackParse("masonry and brickwork");
    assertEquals(result.categories, ["Masonry"]);
  });

  await t.step("infers Tutor from tutor keyword", () => {
    const result = fallbackParse("tutor for mathematics");
    assertEquals(result.categories, ["Tutor"]);
  });

  await t.step("infers Web Developer from web keyword", () => {
    const result = fallbackParse("web development and design");
    assertEquals(result.categories, ["Web Developer"]);
  });

  await t.step("infers Cleaning from clean keyword", () => {
    const result = fallbackParse("cleaning services for homes");
    assertEquals(result.categories, ["Cleaning"]);
  });

  await t.step("infers Moving from move keyword", () => {
    const result = fallbackParse("I move furniture between houses");
    assertEquals(result.categories, ["Moving"]);
  });
});

// ─── Tests: extractJson ──────────────────────────────────────────────

Deno.test("extractJson", async (t) => {
  await t.step("parses clean JSON response", () => {
    const raw = JSON.stringify({
      bio: "Professional plumber with 5 years of experience.",
      categories: ["Plumbing"],
    });
    const result = extractJson(raw);
    assertEquals(result.bio, "Professional plumber with 5 years of experience.");
    assertEquals(result.categories, ["Plumbing"]);
  });

  await t.step("strips markdown code fences", () => {
    const raw = "```json\n{\"bio\": \"Electrician\", \"categories\": [\"Electrical\"]}\n```";
    const result = extractJson(raw);
    assertEquals(result.bio, "Electrician");
    assertEquals(result.categories, ["Electrical"]);
  });

  await t.step("strips markdown fences without json tag", () => {
    const raw = "```\n{\"bio\": \"Painter\", \"categories\": [\"Painting\"]}\n```";
    const result = extractJson(raw);
    assertEquals(result.bio, "Painter");
  });

  await t.step("extracts JSON from text with surrounding content", () => {
    const raw = "Here is the profile: {\"bio\": \"Chef\", \"categories\": [\"Cook\"]} Best regards";
    const result = extractJson(raw);
    assertEquals(result.bio, "Chef");
    assertEquals(result.categories, ["Cook"]);
  });

  await t.step("falls back to keyword parsing on invalid JSON", () => {
    const result = extractJson("Not JSON. I am a plumber.");
    assertStringIncludes(result.bio, "Professional with experience in Plumbing");
    assertEquals(result.categories, ["Plumbing"]);
  });

  await t.step("filters out invalid categories", () => {
    const raw = JSON.stringify({
      bio: "Multi-talented worker",
      categories: ["Plumbing", "InvalidCategory", "Cleaning", "AlsoInvalid"],
    });
    const result = extractJson(raw);
    assertEquals(result.categories, ["Plumbing", "Cleaning"]);
  });

  await t.step("returns empty categories when none are valid", () => {
    const raw = JSON.stringify({
      bio: "Special skills",
      categories: ["Unknown1", "Unknown2"],
    });
    const result = extractJson(raw);
    assertEquals(result.categories, []);
  });

  await t.step("handles missing bio field with empty string", () => {
    const raw = JSON.stringify({
      categories: ["Plumbing"],
    });
    const result = extractJson(raw);
    assertEquals(result.bio, "");
  });
});
