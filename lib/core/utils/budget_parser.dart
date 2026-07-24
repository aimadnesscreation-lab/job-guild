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
    'budget',
    'rs',
    'rupees',
    'rupee',
    'pkr',
    'price',
    'cost',
    'pay',
    'rate',
    'fee',
    'charge',
    'salary',
    'kitne',
    'kitna',
    'qimat',
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
        if (scaled < 100) {
          continue;
        }
        if (scaled > 100000) {
          continue;
        }

        // Skip numbers that might be phone numbers (10-12 digits starting 03 or 92)
        final rawStr = match.group(0)!;
        if ((rawStr.startsWith('03') && rawStr.length >= 10) ||
            (rawStr.startsWith('92') && rawStr.length >= 11)) {
          continue;
        }

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
/// Uses word-boundary regex matching to prevent false positives (e.g.
/// "move" matching inside "remove", "movement", or "improve").
String guessCategory(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('plumb')) return 'Plumbing';
  if (lower.contains('electr')) return 'Electrical';
  if (lower.contains('paint')) return 'Painting';
  if (lower.contains('carpent')) return 'Carpentry';
  if (RegExp(r'\bclean(ing|er)?\b').hasMatch(lower)) return 'Cleaning';
  if (lower.contains('tutor') || lower.contains('teach')) return 'Tutor';
  if (lower.contains('mechanic')) return 'Mechanic';
  if (RegExp(r'\bcook(ing|er)?\b').hasMatch(lower) ||
      RegExp(r'\bfood\b').hasMatch(lower)) {
    return 'Cook';
  }
  if (RegExp(r'\bmove|\bshift(ing|er)?\b').hasMatch(lower)) return 'Moving';
  if (lower.contains('photo')) return 'Photographer';
  if (lower.contains('laptop') || lower.contains('computer'))
    return 'Laptop Repair';
  if (RegExp(r'\bmobile\b').hasMatch(lower) ||
      RegExp(r'\bphone\b').hasMatch(lower)) {
    return 'Mobile Repair';
  }
  if (RegExp(r'\bweb\b').hasMatch(lower) ||
      RegExp(r'\bwebsite\b').hasMatch(lower)) {
    return 'Web Developer';
  }
  if (lower.contains('mason')) return 'Masonry';
  if (lower.contains('weld')) return 'Welding';
  if (RegExp(r'\bbike\b').hasMatch(lower)) return 'Bike Repair';
  if (RegExp(r'\bcar\s*wash\b').hasMatch(lower)) return 'Car Wash';
  if (RegExp(r'\bdj\b').hasMatch(lower)) return 'DJ';
  if (lower.contains('beaut')) return 'Beauty';
  if (lower.contains('health') ||
      lower.contains('medi') ||
      lower.contains('nurse') ||
      lower.contains('doctor')) {
    return 'Healthcare';
  }
  if (RegExp(r'\bpet\b').hasMatch(lower) ||
      RegExp(r'\bdog\b').hasMatch(lower) ||
      RegExp(r'\bcat\b').hasMatch(lower)) {
    return 'Pet Care';
  }
  if (RegExp(r'\blabor\b').hasMatch(lower) ||
      RegExp(r'\blabour\b').hasMatch(lower) ||
      RegExp(r'\bgeneral\b').hasMatch(lower)) {
    return 'General Labor';
  }
  if (lower.contains('teacher') || RegExp(r'\blanguage\b').hasMatch(lower)) {
    return 'Language Teacher';
  }
  if (lower.contains('steel')) return 'Steel Fixing';
  return 'General Labor';
}

/// Detect urgency level from freeform text.
String guessUrgency(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('urgent') ||
      lower.contains('emergency') ||
      lower.contains('asap')) {
    return 'instant';
  }
  if (lower.contains('next') ||
      lower.contains('tomorrow') ||
      lower.contains('schedule')) {
    return 'scheduled';
  }
  return 'today';
}

/// Estimate duration in hours from freeform text.
/// Only matches explicit duration indicators (e.g. "2 hours", "all day")
/// and ignores scheduling words like "next week" / "tomorrow."
int estimateDuration(String input) {
  final lower = input.toLowerCase();
  // Explicit duration with a number: "3 hours", "2hrs", "5 hour"
  final numericMatch = RegExp(
    r'(\d+)\s*(?:hour|hr)',
    caseSensitive: false,
  ).firstMatch(lower);
  if (numericMatch != null) {
    final hours = int.tryParse(numericMatch.group(1)!) ?? 1;
    return hours.clamp(1, 40);
  }
  // Explicit duration without number: "for an hour", "a few hours"
  if (lower.contains('hour') || lower.contains('hr')) return 1;
  // Explicit duration: "all day", "full day", "one day"
  if (lower.contains('day')) return 8;
  // Ignore "week" unless it's clearly "a week's work" style
  if (RegExp(r'\d+\s*week|week\s*(of|long)').hasMatch(lower)) return 40;
  return 2;
}
