/// Shared budget extraction and keyword-based job parsing utilities.
///
/// Used by both [OpenRouterService] (mock fallback) and [PostJobNotifier]
/// (keyword mock parse) to avoid duplicated logic with inconsistent behavior.
library;

/// Extract a budget amount from freeform text. Only considers numbers that
/// appear near budget-related keywords (rupees, budget, price, cost, etc.)
/// to avoid matching house numbers, phone numbers, and other non-budget text.
///
/// Falls back to a category-based default if no budget-adjacent number is found.
int estimateBudget(String input, String category) {
  final lower = input.toLowerCase();

  // Budget-related context words in English and Urdu/Roman Urdu.
  final budgetWords = [
    'budget', 'rs', 'rupees', 'rupee', 'pkr', 'price',
    'cost', 'pay', 'rate', 'fee', 'charge', 'salary',
    'kitne', 'kitna', 'qimat',
  ];

  final digitRegex = RegExp(r'(\d{1,3}(?:,\d{3})+|\d+)\s*([kK])?');
  int? bestValue;
  var bestHasK = false;

  for (final word in budgetWords) {
    // Find occurrences of the word and look for numbers nearby (+-50 chars).
    var start = 0;
    while (true) {
      final idx = lower.indexOf(word, start);
      if (idx == -1) break;
      start = idx + 1;

      // Extract a window of text around the keyword.
      final windowStart = (idx - 50).clamp(0, lower.length);
      final windowEnd = (idx + word.length + 50).clamp(0, lower.length);
      final window = lower.substring(windowStart, windowEnd);

      final matches = digitRegex.allMatches(window);
      for (final match in matches) {
        final raw = match.group(1)!.replaceAll(',', '');
        final value = int.parse(raw);
        final hasK = match.group(2) != null;
        final scaled = hasK ? value * 1000 : value;

        // Skip values that are too small or too large to be budgets.
        if (scaled < 100) { continue; }
        if (scaled > 100000) { continue; }

        // Skip numbers that might be phone numbers (10-12 digits starting 03 or 92)
        final rawStr = match.group(0)!;
        if ((rawStr.startsWith('03') && rawStr.length >= 10) ||
            (rawStr.startsWith('92') && rawStr.length >= 11)) { continue; }

        // Prefer K-suffix values, then larger values.
        if (bestValue == null ||
            (hasK && !bestHasK) ||
            (hasK == bestHasK && scaled > bestValue)) {
          bestValue = scaled;
          bestHasK = hasK;
        }
      }
    }
  }

  if (bestValue != null) return bestValue;

  // Fallback: category-based default estimates.
  const budgets = {
    'Plumbing': 3000,
    'Electrical': 3500,
    'Painting': 4000,
    'Carpentry': 3500,
    'Masonry': 5000,
    'Cleaning': 1500,
    'Tutor': 500,
    'Mechanic': 3000,
    'Moving': 5000,
    'Cook': 3000,
    'Photographer': 5000,
    'Laptop Repair': 2500,
    'Mobile Repair': 1500,
    'Web Developer': 5000,
    'Welding': 4000,
    'Bike Repair': 1500,
    'Car Wash': 1000,
    'DJ': 8000,
    'Beauty': 1500,
    'Healthcare': 2000,
    'Pet Care': 1000,
    'Language Teacher': 800,
    'Steel Fixing': 5000,
    'General Labor': 2000,
  };
  return budgets[category] ?? 2000;
}

/// Keyword-based category detection from freeform job description text.
String guessCategory(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('plumb')) return 'Plumbing';
  if (lower.contains('electr')) return 'Electrical';
  if (lower.contains('paint')) return 'Painting';
  if (lower.contains('carpent')) return 'Carpentry';
  if (lower.contains('clean')) return 'Cleaning';
  if (lower.contains('tutor') || lower.contains('teach')) return 'Tutor';
  if (lower.contains('mechanic')) return 'Mechanic';
  if (lower.contains('cook') || lower.contains('food')) return 'Cook';
  if (lower.contains('move') || lower.contains('shift')) return 'Moving';
  if (lower.contains('photo')) return 'Photographer';
  if (lower.contains('laptop') || lower.contains('computer')) return 'Laptop Repair';
  if (lower.contains('mobile') || lower.contains('phone')) return 'Mobile Repair';
  if (lower.contains('web') || lower.contains('website')) return 'Web Developer';
  if (lower.contains('mason')) return 'Masonry';
  if (lower.contains('weld')) return 'Welding';
  if (lower.contains('bike')) return 'Bike Repair';
  if (lower.contains('car wash')) return 'Car Wash';
  if (lower.contains('dj')) return 'DJ';
  if (lower.contains('beaut')) return 'Beauty';
  if (lower.contains('health') || lower.contains('medi')) return 'Healthcare';
  if (lower.contains('pet') || lower.contains('dog') || lower.contains('cat')) return 'Pet Care';
  if (lower.contains('labor') || lower.contains('labour')) return 'General Labor';
  if (lower.contains('teacher') || lower.contains('language')) return 'Language Teacher';
  if (lower.contains('steel')) return 'Steel Fixing';
  return 'General Labor';
}

/// Detect urgency level from freeform text.
String guessUrgency(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('urgent') || lower.contains('emergency') || lower.contains('asap')) {
    return 'instant';
  }
  if (lower.contains('next') || lower.contains('tomorrow') || lower.contains('schedule')) {
    return 'scheduled';
  }
  return 'today';
}

/// Estimate duration in hours from freeform text.
/// Only matches explicit duration indicators (e.g. "2 hours", "all day")
/// and ignores scheduling words like "next week" / "tomorrow."
int estimateDuration(String input) {
  final lower = input.toLowerCase();
  // Explicit duration: "2 hours", "3hrs", "for an hour"
  if (lower.contains('hour') || lower.contains('hr')) return 1;
  // Explicit duration: "all day", "full day", "one day"
  if (lower.contains('day')) return 8;
  // Ignore "week" unless it's clearly "a week's work" style
  if (RegExp(r'\d+\s*week|week\s*(of|long)').hasMatch(lower)) return 40;
  return 2;
}
