// Shared OpenRouter client for Local Services Marketplace Edge Functions.
// Eliminates the duplicated callOpenRouter logic across bright-api, rapid-worker,
// and any future functions.

const OPENROUTER_BASE_URL =
  Deno.env.get("OPENROUTER_BASE_URL") || "https://openrouter.ai/api/v1";
const APP_REFERER = Deno.env.get("SUPABASE_URL") || "https://localservices.app";

export interface OpenRouterOptions {
  /** Model temperature (0.0 - 2.0) */
  temperature?: number;
  /** Maximum tokens to generate */
  maxTokens?: number;
  /** Primary model identifier, e.g. "google/gemma-4-26b-a4b-it:free" */
  model?: string;
}

export interface OpenRouterCallResult {
  content: string;
  model: string;
}

/**
 * Call the OpenRouter chat completions API.
 *
 * Features:
 *   - Validates the API key is present.
 *   - Retries once with the openrouter/free fallback on 429/502/503.
 *   - Returns the raw assistant content string.
 */
export async function callOpenRouter(
  systemPrompt: string,
  userPrompt: string,
  options: OpenRouterOptions = {},
): Promise<string> {
  const apiKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!apiKey) {
    throw new Error(
      "OPENROUTER_API_KEY environment variable is not set. " +
        "Run: supabase secrets set OPENROUTER_API_KEY=<your-key>",
    );
  }

  const {
    temperature = 0.1,
    maxTokens = 400,
    model = Deno.env.get("OPENROUTER_MODEL") || "google/gemma-4-26b-a4b-it:free",
  } = options;

  const response = await fetch(`${OPENROUTER_BASE_URL}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
      "HTTP-Referer": APP_REFERER,
      "X-Title": "Local Services Marketplace",
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: "system",
          content: `${systemPrompt}\n\n` +
            "IMPORTANT: Return ONLY valid JSON. No markdown fences. No explanation. " +
            "No backticks. Just the raw JSON object.",
        },
        { role: "user", content: userPrompt },
      ],
      temperature,
      max_tokens: maxTokens,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error("[OpenRouter] API error:", response.status, errorText);

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
            temperature,
            max_tokens: maxTokens,
          }),
        },
      );
      if (!retryResponse.ok) {
        throw new Error(`OpenRouter API error (retry): ${retryResponse.status}`);
      }
      const retryData = await retryResponse.json();
      return retryData.choices?.[0]?.message?.content?.trim() || "";
    }

    throw new Error(`OpenRouter API error: ${response.status} - ${errorText}`);
  }

  const data = await response.json();
  return data.choices?.[0]?.message?.content?.trim() || "";
}
