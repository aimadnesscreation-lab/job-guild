// Supabase Edge Function: bright-api
// Proxies job description parsing requests to OpenRouter's free AI models.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { callOpenRouter } from "../_shared/openrouter.ts";
import { 
  findBestCategoryMatch, 
  estimateBudget, 
  VALID_CATEGORIES, 
  Category,
  BUDGET_MIN_PKR,
  BUDGET_MAX_PKR
} from "../_shared/utils.ts";

interface ParseRequestBody {
  description: string;
}

interface ParseResponse {
  category: Category;
  urgency: string;
  suggested_budget_pkr: number;
  estimated_duration_hours: number;
  required_skills: string[];
}

const VALID_URGENCIES = ["instant", "today", "scheduled"] as const;

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
    console.warn(
      "[bright-api] Failed to parse LLM response as JSON, using keyword fallback",
    );
    return fallbackParse(raw);
  }

  // Validate and type-check fields
  const category = findBestCategoryMatch(
    typeof parsed.category === 'string' ? parsed.category : ""
  );
  
  const urgencyRaw = typeof parsed.urgency === 'string' ? parsed.urgency : "";
  const urgency = VALID_URGENCIES.includes(urgencyRaw as any)
    ? (urgencyRaw as typeof VALID_URGENCIES[number])
    : "today";

  // Validate skills
  let skills: string[];
  if (Array.isArray(parsed.required_skills)) {
    skills = (parsed.required_skills as unknown[]).map((s) => String(s));
  } else {
    skills = [category];
  }

  // Validate numeric fields — fall back to estimateBudget when budget is zero
  // or negative, since PKR 0 looks broken in the UI.
  const budget = typeof parsed.suggested_budget_pkr === "number" && parsed.suggested_budget_pkr > 0
        ? Math.max(1, parsed.suggested_budget_pkr)
        : estimateBudget(category, "");
  
  const duration = typeof parsed.estimated_duration_hours === "number"
        ? Math.max(1, Math.min(40, parsed.estimated_duration_hours))
        : 2;

  return {
    category,
    urgency,
    suggested_budget_pkr: budget,
    estimated_duration_hours: duration,
    required_skills: skills,
  };
}

/**
 * Fallback keyword-based parsing when AI is unavailable.
 */
function fallbackParse(text: string): ParseResponse {
  const lower = text.toLowerCase();
  
  // Use findBestCategoryMatch for keyword detection (it handles partials)
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

serve(async (req) => {
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
      const rawResponse = await callOpenRouter(systemPrompt, userPrompt);
      console.log(`[bright-api] LLM response: ${rawResponse.substring(0, 200)}...`);
      result = extractJson(rawResponse);
    } catch (aiError) {
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
