// Supabase Edge Function: bright-api
// Proxies job description parsing requests to OpenRouter's free AI models.
//
// Environment variables:
// - OPENROUTER_API_KEY: Your OpenRouter API key (set via `supabase secrets set`)
// - OPENROUTER_BASE_URL: Optional, defaults to https://openrouter.ai/api/v1
//
// Called from: Flutter client via supabase.functions.invoke('bright-api', body)
//
// Endpoint: POST /bright-api
// Body: { "description": "Freeform job description text" }
// Response: {
//   "category": "Plumbing",
//   "urgency": "instant" | "today" | "scheduled",
//   "suggested_budget_pkr": 2500,
//   "estimated_duration_hours": 2,
//   "required_skills": ["Plumbing"]
// }

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

interface ParseRequestBody {
  description: string;
}

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

const OPENROUTER_BASE_URL =
  Deno.env.get("OPENROUTER_BASE_URL") || "https://openrouter.ai/api/v1";

const APP_REFERER = Deno.env.get("SUPABASE_URL") || "https://localservices.app";

/**
 * Call OpenRouter chat completions API with a free model.
 * Uses google/gemma-4-26b-a4b-it:free by default (modern, reliable for JSON output).
 * Falls back to openrouter/free auto-router if rate-limited.
 */
async function callOpenRouter(
  systemPrompt: string,
  userPrompt: string,
): Promise<string> {
  const apiKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!apiKey) {
    throw new Error(
      "OPENROUTER_API_KEY environment variable is not set. " +
        "Run: supabase secrets set OPENROUTER_API_KEY=<your-key>",
    );
  }

  const response = await fetch(`${OPENROUTER_BASE_URL}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,            "HTTP-Referer": APP_REFERER,
      "X-Title": "Local Services Marketplace",
    },
    body: JSON.stringify({
      // Google Gemma 4 — modern free model, reliable for structured JSON extraction
      model: "google/gemma-4-26b-a4b-it:free",
      messages: [
        {
          role: "system",
          content:
            `${systemPrompt}\n\n` +
            "IMPORTANT: Return ONLY valid JSON. No markdown fences. No explanation. " +
            "No backticks. Just the raw JSON object.",
        },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.1,
      max_tokens: 400,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error("[OpenRouter] API error:", response.status, errorText);

    // If the primary model fails, retry with openrouter/free auto-router
    // which automatically selects the best available free model
    if (response.status === 429 || response.status === 503 || response.status === 502) {
      console.log("[OpenRouter] Primary model failed, retrying with openrouter/free...");
      const retryResponse = await fetch(
        `${OPENROUTER_BASE_URL}/chat/completions`,
        {
          method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
        "HTTP-Referer": APP_REFERER,
        "X-Title": "Local Services Marketplace",
      },
          body: JSON.stringify({
            model: "openrouter/free",
            messages: [
              {
                role: "system",
                content: `${systemPrompt}\n\nReturn ONLY valid JSON. No markdown.`,
              },
              { role: "user", content: userPrompt },
            ],
            temperature: 0.1,
            max_tokens: 400,
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
  const content = data.choices?.[0]?.message?.content || "";
  return content.trim();
}

/**
 * Parse the raw LLM response text into a structured JSON object.
 * Handles cases where the model includes markdown fences or extra text.
 */
function extractJson(raw: string): ParseResponse {
  // Strip markdown code fences if present
  let cleaned = raw
    .replace(/^```(?:json)?\s*/gm, "")
    .replace(/\s*```$/gm, "")
    .trim();

  // Try to find a JSON object in the response
  const jsonMatch = cleaned.match(/\{[\s\S]*\}/);
  if (jsonMatch) {
    cleaned = jsonMatch[0];
  }

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(cleaned) as Record<string, unknown>;
  } catch {
    // If JSON parsing fails, do basic keyword extraction
    console.warn(
      "[bright-api] Failed to parse LLM response as JSON, using keyword fallback",
    );
    return fallbackParse(raw);
  }

  const category = findBestMatch(
    (parsed.category as string) || "",
    VALID_CATEGORIES as unknown as string[],
  );
  const urgency = VALID_URGENCIES.includes(parsed.urgency as string)
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

/**
 * Find the best matching valid category from the LLM output.
 * Handles case differences and partial matches.
 */
function findBestMatch(input: string, validOptions: string[]): string {
  const lower = input.toLowerCase().trim();

  // Exact match (case-insensitive)
  const exact = validOptions.find(
    (o) => o.toLowerCase() === lower,
  );
  if (exact) return exact;

  // Partial match
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
  // Try to extract a budget hint from the text e.g. "5000", "5k", "3rs"
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

serve(async (req) => {
  // Only accept POST requests
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body: ParseRequestBody = await req.json();

    if (!body.description || body.description.trim().length < 3) {
      return new Response(
        JSON.stringify({ error: "Description must be at least 3 characters" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const description = body.description.trim();
    console.log(`[bright-api] Parsing: "${description.substring(0, 100)}..."`);

    const systemPrompt =
      "You are a job parser for a local services marketplace in Pakistan. " +
      "Extract structured data from the user's job description. " +
      `Valid categories: ${VALID_CATEGORIES.join(", ")}. ` +
      'Urgency must be "instant", "today", or "scheduled". Budget is in PKR. Duration is in hours.';

    const userPrompt =
      `Parse this job request: "${description}"\n\n` +
      'Return JSON with exactly:\n' +
      '{\n' +
      '  "category": string (one of the valid categories),\n' +
      '  "urgency": "instant"|"today"|"scheduled",\n' +
      '  "suggested_budget_pkr": number,\n' +
      '  "estimated_duration_hours": number,\n' +
      '  "required_skills": string[]\n' +
      '}';

    let result: ParseResponse;

    try {
      // Try AI parsing first
      const rawResponse = await callOpenRouter(systemPrompt, userPrompt);
      console.log(`[bright-api] LLM response: ${rawResponse.substring(0, 200)}...`);
      result = extractJson(rawResponse);
    } catch (aiError) {
      // Fall back to keyword-based parsing if AI is unavailable
      console.warn(
        `[bright-api] AI unavailable, using keyword fallback: ${aiError}`,
      );
      result = fallbackParse(description);
    }

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[bright-api] Error:", error);
    return new Response(
      JSON.stringify({
        error: "Failed to parse job description",
        details: error instanceof Error ? error.message : String(error),
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
