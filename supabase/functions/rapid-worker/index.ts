// Supabase Edge Function: rapid-worker
// Generates professional worker bios and suggests categories from freeform text.
//
// Environment variables:
// - OPENROUTER_API_KEY: Your OpenRouter API key (shared with bright-api)
// - OPENROUTER_BASE_URL: Optional, defaults to https://openrouter.ai/api/v1
//
// Called from: Flutter client via supabase.functions.invoke('rapid-worker', body)
//
// Endpoint: POST /rapid-worker
// Body: {
//   "raw_description": "I worked in construction for 8 years, mostly plumbing and tiling."
// }
// Response: {
//   "bio": "Professional plumber and tiler with 8 years of construction experience...",
//   "categories": ["Plumbing", "Masonry", "General Labor"]
// }

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

interface ProfileRequestBody {
  raw_description: string;
}

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

const OPENROUTER_BASE_URL =
  Deno.env.get("OPENROUTER_BASE_URL") || "https://openrouter.ai/api/v1";

/**
 * Call OpenRouter chat completions API.
 * Uses google/gemma-4-26b-a4b-it:free for text generation (profiles).
 * Falls back to openrouter/free auto-router if rate-limited.
 */
async function callOpenRouter(
  systemPrompt: string,
  userPrompt: string,
): Promise<string> {
  const apiKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!apiKey) {
    throw new Error("OPENROUTER_API_KEY environment variable is not set.");
  }

  const response = await fetch(`${OPENROUTER_BASE_URL}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
      "HTTP-Referer": "https://izjfugswuwyinaeauhvz.supabase.co",
      "X-Title": "Local Services Marketplace",
    },
    body: JSON.stringify({
      // Google Gemma 4 — modern free model, reliable for profile generation
      model: "google/gemma-4-26b-a4b-it:free",
      messages: [
        {
          role: "system",
          content: `${systemPrompt}\n\nReturn ONLY valid JSON. No markdown fences. No explanation. Just the raw JSON object.`,
        },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.5,
      max_tokens: 600,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error("[OpenRouter] API error:", response.status, errorText);

    // Rate-limit or server error fallback
    if (response.status === 429 || response.status === 503 || response.status === 502) {
      console.log("[rapid-worker] Primary model failed, retrying with openrouter/free...");
      const retryResponse = await fetch(
        `${OPENROUTER_BASE_URL}/chat/completions`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${apiKey}`,
            "HTTP-Referer": "https://izjfugswuwyinaeauhvz.supabase.co",
            "X-Title": "Local Services Marketplace",
          },
          body: JSON.stringify({
            model: "openrouter/free",
            messages: [
              {
                role: "system",
                content: `${systemPrompt}\n\nReturn ONLY valid JSON.`,
              },
              { role: "user", content: userPrompt },
            ],
            temperature: 0.5,
            max_tokens: 600,
          }),
        },
      );
      if (!retryResponse.ok) {
        throw new Error(
          `OpenRouter API error (retry): ${retryResponse.status}`,
        );
      }
      const retryData = await retryResponse.json();
      return retryData.choices?.[0]?.message?.content || "";
    }

    throw new Error(`OpenRouter API error: ${response.status} - ${errorText}`);
  }

  const data = await response.json();
  return data.choices?.[0]?.message?.content?.trim() || "";
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
    console.warn("[rapid-worker] Failed to parse LLM response, using fallback");
    return fallbackParse(raw);
  }

  return {
    bio: (parsed.bio as string) || "",
    categories: (parsed.categories as string[])?.filter((c) =>
      VALID_CATEGORIES.includes(c)
    ) || [],
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
      if (matched.length < 3) matched.push(category);
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

serve(async (req) => {
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
      const rawResponse = await callOpenRouter(systemPrompt, userPrompt);
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
});
