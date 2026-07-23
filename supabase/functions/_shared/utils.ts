// Shared utilities for Local Services Marketplace Edge Functions.

/**
 * Constants for business logic.
 */
export const BUDGET_MIN_PKR = 100;
export const BUDGET_MAX_PKR = 100000;
export const TOKEN_EXPIRY_BUFFER_MS = 300_000; // 5 minutes

/**
 * Proper Base64URL encoding per RFC 4648.
 * Replaces + with -, / with _, and removes padding =.
 */
export function encodeBase64Url(data: string | Uint8Array): string {
  let b64: string;
  if (typeof data === "string") {
    b64 = btoa(data);
  } else {
    // Avoid stack overflow on large Uint8Arrays by using a loop or chunked approach.
    // For signatures (256 bytes), this is safe, but for consistency we use a robust method.
    b64 = btoa(Array.from(data, (byte) => String.fromCharCode(byte)).join(""));
  }
  return b64
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
}

/**
 * Valid categories for the marketplace.
 */
export const VALID_CATEGORIES = [
  "Plumbing", "Electrical", "Painting", "Carpentry", "Masonry",
  "Mechanic", "Bike Repair", "Car Wash",
  "Labor", "Welding", "Steel Fixing",
  "Tutor", "Language Teacher",
  "Laptop Repair", "Mobile Repair", "Web Developer",
  "Photographer", "DJ", "Cook",
  "Cleaning", "Moving", "Healthcare", "Beauty", "Pet Care",
  "General Labor",
] as const;

export type Category = (typeof VALID_CATEGORIES)[number];

/**
 * Find the best matching valid category from a string.
 */
export function findBestCategoryMatch(input: string): Category {
  const lower = input.toLowerCase().trim();
  if (!lower) return "General Labor";

  // Exact match (case-insensitive)
  const exact = VALID_CATEGORIES.find(
    (o) => o.toLowerCase() === lower,
  );
  if (exact) return exact;

  // Partial match
  const partial = VALID_CATEGORIES.find(
    (o) => o.toLowerCase().includes(lower) || lower.includes(o.toLowerCase()),
  );
  if (partial) return partial;

  return "General Labor";
}

/**
 * Estimate a reasonable budget based on category and any budget hints in text.
 * Improved regex to anchor around budget keywords and handle rs/k suffixes properly.
 */
export function estimateBudget(category: string, text: string): number {
  const lower = text.toLowerCase();
  
  // Look for budget keywords and capture the nearest number (50 char window)
  const budgetKeywords = ["budget", "price", "rate", "cost", "pk", "rs"];
  let extractedValue: number | null = null;
  let hasK = false;

  const matches = Array.from(lower.matchAll(/(\d{1,3}(?:,\d{3})+|\d+)\s*(k|rs|pkr)?/gi));
  
  for (const match of matches) {
    const raw = match[1].replace(/,/g, "");
    const num = parseInt(raw, 10);
    const suffix = match[2]?.toLowerCase();
    const currentHasK = suffix === "k";
    const scaled = currentHasK ? num * 1000 : num;

    // Is this number near a budget keyword?
    const index = match.index || 0;
    const surrounding = lower.substring(Math.max(0, index - 30), Math.min(lower.length, index + 30));
    const isNearKeyword = budgetKeywords.some(kw => surrounding.includes(kw));

    if (
      extractedValue === null ||
      (currentHasK && !hasK) ||
      (isNearKeyword && scaled >= BUDGET_MIN_PKR && scaled <= BUDGET_MAX_PKR)
    ) {
      // Clamping and validation
      if (scaled >= BUDGET_MIN_PKR && scaled <= BUDGET_MAX_PKR) {
        extractedValue = scaled;
        hasK = currentHasK;
      }
    }
  }

  if (extractedValue !== null) return extractedValue;

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
