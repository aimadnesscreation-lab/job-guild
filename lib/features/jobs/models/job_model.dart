/// Matches the `jobs` table in the Supabase schema.
///
/// Location is stored as PostGIS geography (POINT, 4326) in the database.
/// Internally we keep lat/lng as doubles for convenience.
class Job {
  final String id;
  final String employerId;
  final int categoryId;
  final String title;
  final String description;
  final JobAiMetadata? aiExtractedMetadata;
  final int? budgetAmount;
  final BudgetType budgetType;
  final String? locationText;
  final double lat;
  final double lng;
  final JobStatus status;
  final Urgency urgency;
  final DateTime? scheduledFor;
  final DateTime createdAt;

  Job({
    this.id = '',
    this.employerId = '',
    this.categoryId = 1,
    this.title = '',
    this.description = '',
    this.aiExtractedMetadata,
    this.budgetAmount,
    this.budgetType = BudgetType.negotiable,
    this.locationText,
    this.lat = 31.5204,
    this.lng = 74.3587,
    this.status = JobStatus.open,
    this.urgency = Urgency.today,
    this.scheduledFor,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Parse a PostGIS geography value from the database response.
  ///
  /// The database stores location as `location_coords GEOGRAPHY(POINT,4326)`.
  /// PostgREST returns it as a GeoJSON object:
  ///   { "type": "Point", "coordinates": [lng, lat] }
  /// Or as WKT string:
  ///   "POINT(lng lat)"
  ///
  /// Returns `(null, null)` when no coordinates are found in any format,
  /// allowing callers to distinguish missing data from valid (0,0) coords.
  static (double?, double?) _parseCoordinates(Map<String, dynamic> json) {
    // Try reading from a parsed GeoJSON "location_coords" field
    final coords = json['location_coords'];
    if (coords is Map<String, dynamic>) {
      final coordsList = coords['coordinates'] as List<dynamic>?;
      if (coordsList != null && coordsList.length >= 2) {
        return (_parseDouble(coordsList[1]), _parseDouble(coordsList[0]));
      }
    }
    // Try WKT string format
    if (coords is String) {
      final match = RegExp(
        r'POINT\s*\(([^\s]+)\s+([^\s]+)\)',
        caseSensitive: false,
      ).firstMatch(coords);
      if (match != null) {
        return (_parseDouble(match.group(2)), _parseDouble(match.group(1)));
      }
    }
    // Fallback: read old-style separate lat/lng columns (pre-migration data).
    // Use null-check instead of zero-check so that valid (0,0) coordinates
    // (rare but possible) are not incorrectly treated as missing data.
    // FIX (Bug #14): Detect missing coordinates via null, not zero values.
    final rawLat = json['location_lat'];
    final rawLng = json['location_lng'];
    if (rawLat != null && rawLng != null) {
      return (_parseDouble(rawLat), _parseDouble(rawLng));
    }
    return (null, null);
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    final (parsedLat, parsedLng) = _parseCoordinates(json);

    // FIX (Bug #14): Use null checks instead of zero-check so valid (0,0)
    // coordinates are not incorrectly treated as missing data.
    final lat = parsedLat ?? 31.5204;
    final lng = parsedLng ?? 74.3587;

    return Job(
      id: json['id'] as String? ?? '',
      employerId: json['employer_id'] as String? ?? '',
      categoryId: json['category_id'] as int? ?? 1,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      aiExtractedMetadata: json['ai_extracted_metadata'] != null
          ? JobAiMetadata.fromJson(
              json['ai_extracted_metadata'] as Map<String, dynamic>,
            )
          : null,
      budgetAmount: json['budget_amount'] is int
          ? json['budget_amount'] as int
          : (json['budget_amount'] as num?)?.toInt(),
      budgetType: Job.parseBudgetType(json['budget_type'] as String?),
      locationText: json['location_text'] as String?,
      lat: lat,
      lng: lng,
      status: Job.parseJobStatus(json['status'] as String?),
      urgency: Job.parseUrgency(json['urgency'] as String?),
      scheduledFor: json['scheduled_for'] != null
          ? DateTime.parse(json['scheduled_for'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Converts to JSON for REST API.
  ///
  /// For PostGIS geography columns, we send the coordinate as a WKT
  /// string "POINT(lng lat)" which PostgREST and PostGIS understand.
  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'employer_id': employerId,
    'category_id': categoryId,
    'title': title,
    'description': description,
    if (aiExtractedMetadata != null)
      'ai_extracted_metadata': aiExtractedMetadata!.toJson(),
    if (budgetAmount != null) 'budget_amount': budgetAmount,
    'budget_type': budgetType.name,
    if (locationText != null) 'location_text': locationText,
    'location_coords': 'POINT($lng $lat)',
    'status': status.name,
    'urgency': urgency.name,
    if (scheduledFor != null) 'scheduled_for': scheduledFor!.toIso8601String(),
    // NOTE: created_at is intentionally NOT sent — the database default (NOW())
    // handles inserts, and updates should never overwrite the creation timestamp.
  };

  Job copyWith({
    String? id,
    String? employerId,
    int? categoryId,
    String? title,
    String? description,
    JobAiMetadata? aiExtractedMetadata,
    int? budgetAmount,
    BudgetType? budgetType,
    String? locationText,
    double? lat,
    double? lng,
    JobStatus? status,
    Urgency? urgency,
    DateTime? scheduledFor,
    DateTime? createdAt,
    bool clearAiMetadata = false,
    bool clearBudgetAmount = false,
    bool clearLocationText = false,
    bool clearScheduledFor = false,
  }) {
    return Job(
      id: id ?? this.id,
      employerId: employerId ?? this.employerId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      aiExtractedMetadata: clearAiMetadata
          ? null
          : (aiExtractedMetadata ?? this.aiExtractedMetadata),
      budgetAmount: clearBudgetAmount
          ? null
          : (budgetAmount ?? this.budgetAmount),
      budgetType: budgetType ?? this.budgetType,
      locationText: clearLocationText
          ? null
          : (locationText ?? this.locationText),
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      status: status ?? this.status,
      urgency: urgency ?? this.urgency,
      scheduledFor: clearScheduledFor
          ? null
          : (scheduledFor ?? this.scheduledFor),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get budgetDisplay {
    if (budgetAmount == null) return 'Negotiable';
    return 'PKR $budgetAmount';
  }

  bool get isInstant => urgency == Urgency.instant;
  bool get isOpen => status == JobStatus.open;

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static BudgetType parseBudgetType(String? type) {
    switch (type) {
      case 'fixed':
        return BudgetType.fixed;
      case 'hourly':
        return BudgetType.hourly;
      default:
        return BudgetType.negotiable;
    }
  }

  static JobStatus parseJobStatus(String? status) {
    switch (status) {
      case 'open':
        return JobStatus.open;
      case 'hired':
        return JobStatus.hired;
      case 'completed':
        return JobStatus.completed;
      case 'cancelled':
        return JobStatus.cancelled;
      case 'expired':
        return JobStatus.expired;
      default:
        return JobStatus.open;
    }
  }

  static Urgency parseUrgency(String? urgency) {
    switch (urgency) {
      case 'instant':
        return Urgency.instant;
      case 'scheduled':
        return Urgency.scheduled;
      default:
        return Urgency.today;
    }
  }
}

/// AI-extracted metadata from freeform job description
class JobAiMetadata {
  final String category;
  final String urgency;
  final int suggestedBudgetPkr;
  final int estimatedDurationHours;
  final List<String> requiredSkills;

  const JobAiMetadata({
    required this.category,
    required this.urgency,
    required this.suggestedBudgetPkr,
    required this.estimatedDurationHours,
    this.requiredSkills = const [],
  });

  factory JobAiMetadata.fromJson(Map<String, dynamic> json) {
    return JobAiMetadata(
      category: json['category'] as String? ?? '',
      urgency: json['urgency'] as String? ?? 'today',
      suggestedBudgetPkr: (json['suggested_budget_pkr'] as num?)?.toInt() ?? 0,
      estimatedDurationHours:
          (json['estimated_duration_hours'] as num?)?.toInt() ?? 2,
      requiredSkills:
          (json['required_skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'category': category,
    'urgency': urgency,
    'suggested_budget_pkr': suggestedBudgetPkr,
    'estimated_duration_hours': estimatedDurationHours,
    'required_skills': requiredSkills,
  };
}

enum JobStatus { open, hired, completed, cancelled, expired }

enum BudgetType { fixed, hourly, negotiable }

enum Urgency { instant, today, scheduled }

/// Lookup map for category names → IDs
const Map<String, int> categoryNameToId = {
  'Home': 1,
  'Plumbing': 13,
  'Electrical': 14,
  'Painting': 15,
  'Carpentry': 16,
  'Masonry': 17,
  'Vehicles': 2,
  'Mechanic': 18,
  'Bike Repair': 19,
  'Car Wash': 20,
  'Construction': 3,
  'Labor': 21,
  'Welding': 22,
  'Steel Fixing': 23,
  'Education': 4,
  'Tutor': 24,
  'Language Teacher': 25,
  'Technology': 5,
  'Laptop Repair': 26,
  'Mobile Repair': 27,
  'Web Developer': 28,
  'Events': 6,
  'Photographer': 29,
  'DJ': 30,
  'Cook': 31,
  'Cleaning': 7,
  'Moving': 8,
  'Healthcare': 9,
  'Beauty': 10,
  'Pet Care': 11,
  'General Labor': 12,
};
