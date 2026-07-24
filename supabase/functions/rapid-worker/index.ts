// Supabase Edge Function: rapid-worker
// Generates professional worker bios and suggests categories from freeform text.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { callOpenRouter } from "../_shared/openrouter.ts";
import { VALID_CATEGORIES, findBestCategoryMatch } from "../_shared/utils.ts";

interface ProfileRequestBody {
  raw_description: string;
}

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
    console.warn("[rapid-worker] Failed to parse LLM response, using fallback");
    return fallbackParse(raw);
  }

  // Bug #5 fix: Ensure categories is an array before filtering
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

export async function handler(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body: ProfileRequestBody = await req.json();

    if (!body.raw_description || body.raw_description.trim().length < 3) {
      return new Response(
        JSON.stringify({ error: "Description must be at least 3 characters" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const raw = body.raw_description.trim();
    console.log(`[rapid-worker] Generating profile from: "${raw.substring(0, 80)}..."`);

    const systemPrompt =
      "You are a professional profile writer for a local services marketplace in Pakistan. " +
      "Write a 2-3 sentence professional bio based on the user's description. " +
      "Keep it concise, positive, and focused on skills and reliability. " +
      "Also suggest relevant service categories. " +
      `Valid categories: ${VALID_CATEGORIES.join(", ")}.`;

    const userPrompt =
      `Generate a professional bio and suggest categories for someone with this experience: "${raw}"\n\n` +
      'Return JSON with format: {\n  "bio": "2-3 sentence professional bio",\n  "categories": ["Category1", "Category2"]\n}';

    let result: ProfileResponse;

    try {
      const rawResponse = await callOpenRouter(systemPrompt, userPrompt, {
        temperature: 0.5,
        maxTokens: 600,
      });
      console.log(`[rapid-worker] LLM response: "${rawResponse.substring(0, 150)}..."`);
      result = extractJson(rawResponse);

      // Ensure we always have at least one category
      if (result.categories.length === 0) {
        result.categories = fallbackParse(raw).categories;
      }
    } catch (aiError) {
      console.warn(`[rapid-worker] AI unavailable, using fallback: ${aiError}`);
      result = fallbackParse(raw);
    }

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[rapid-worker] Error:", error);
    return new Response(
      JSON.stringify({ error: "Profile generation failed" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
}

// Start the server (only when run directly, not during tests)
if (import.meta.main) serve(handler);
