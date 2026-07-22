import 'package:flutter/material.dart';

/// Matches the `worker_profiles` table in the Supabase schema,
/// plus user fields that are commonly displayed alongside it.
class WorkerProfile {
  final String userId;
  final String fullName;
  final String? profilePhotoUrl;
  final String? headline;
  final String? bio;
  final int yearsExperience;
  final int? hourlyRatePkr;
  final String? fixedRateNote;
  final AvailabilityStatus availabilityStatus;
  final int serviceRadiusKm;
  final double averageRating;
  final int totalJobsCompleted;
  final int responseTimeAvgMinutes;
  final List<String> portfolioMediaUrls;
  final List<String> categories;
  final bool isVerified;
  final bool isFeatured;

  const WorkerProfile({
    required this.userId,
    required this.fullName,
    this.profilePhotoUrl,
    this.headline,
    this.bio,
    this.yearsExperience = 0,
    this.hourlyRatePkr,
    this.fixedRateNote,
    this.availabilityStatus = AvailabilityStatus.offline,
    this.serviceRadiusKm = 10,
    this.averageRating = 0,
    this.totalJobsCompleted = 0,
    this.responseTimeAvgMinutes = 0,
    this.portfolioMediaUrls = const [],
    this.categories = const [],
    this.isVerified = false,
    this.isFeatured = false,
  });

  WorkerProfile copyWith({
    String? userId,
    String? fullName,
    String? profilePhotoUrl,
    String? headline,
    String? bio,
    int? yearsExperience,
    int? hourlyRatePkr,
    String? fixedRateNote,
    AvailabilityStatus? availabilityStatus,
    int? serviceRadiusKm,
    double? averageRating,
    int? totalJobsCompleted,
    int? responseTimeAvgMinutes,
    List<String>? portfolioMediaUrls,
    List<String>? categories,
    bool? isVerified,
    bool? isFeatured,
    bool clearProfilePhoto = false,
    bool clearHeadline = false,
    bool clearBio = false,
    bool clearFixedRateNote = false,
  }) {
    return WorkerProfile(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      profilePhotoUrl: clearProfilePhoto
          ? null
          : (profilePhotoUrl ?? this.profilePhotoUrl),
      headline: clearHeadline ? null : (headline ?? this.headline),
      bio: clearBio ? null : (bio ?? this.bio),
      yearsExperience: yearsExperience ?? this.yearsExperience,
      hourlyRatePkr: hourlyRatePkr ?? this.hourlyRatePkr,
      fixedRateNote: clearFixedRateNote
          ? null
          : (fixedRateNote ?? this.fixedRateNote),
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      averageRating: averageRating ?? this.averageRating,
      totalJobsCompleted: totalJobsCompleted ?? this.totalJobsCompleted,
      responseTimeAvgMinutes:
          responseTimeAvgMinutes ?? this.responseTimeAvgMinutes,
      portfolioMediaUrls: portfolioMediaUrls ?? this.portfolioMediaUrls,
      categories: categories ?? this.categories,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }

  /// A human-readable summary of availability
  String get availabilityLabel {
    switch (availabilityStatus) {
      case AvailabilityStatus.today:
        return 'Available Today';
      case AvailabilityStatus.tomorrow:
        return 'Available Tomorrow';
      case AvailabilityStatus.weekdays:
        return 'Weekdays';
      case AvailabilityStatus.weekends:
        return 'Weekends';
      case AvailabilityStatus.morning:
        return 'Morning Only';
      case AvailabilityStatus.evening:
        return 'Evening Only';
      case AvailabilityStatus.busy:
        return 'Currently Busy';
      case AvailabilityStatus.offline:
        return 'Offline';
    }
  }

  factory WorkerProfile.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return WorkerProfile(
      userId: json['id'] as String? ?? '',
      fullName:
          user?['full_name'] as String? ?? json['full_name'] as String? ?? '',
      profilePhotoUrl:
          user?['profile_photo_url'] as String? ??
          json['profile_photo_url'] as String?,
      headline: json['headline'] as String?,
      bio: json['bio'] as String?,
      yearsExperience: json['years_experience'] as int? ?? 0,
      hourlyRatePkr: json['hourly_rate_pkr'] as int?,
      fixedRateNote: json['fixed_rate_note'] as String?,
      availabilityStatus: AvailabilityStatus.values.firstWhere(
        (s) => s.name == json['availability_status'],
        orElse: () => AvailabilityStatus.offline,
      ),
      serviceRadiusKm: json['service_radius_km'] as int? ?? 10,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalJobsCompleted: json['total_jobs_completed'] as int? ?? 0,
      responseTimeAvgMinutes: json['response_time_avg_minutes'] as int? ?? 0,
      portfolioMediaUrls:
          (json['portfolio_media'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isVerified:
          user?['is_verified'] as bool? ??
          json['is_verified'] as bool? ??
          false,
      isFeatured: json['is_featured'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    // NOTE: `full_name` and `is_verified` live on the `users` table, NOT
    // `worker_profiles` (see supabase/migrations). They are intentionally
    // excluded here — sending them causes PostgREST to reject the upsert
    // with HTTP 400. The name is persisted via WorkerRepository.updateUserName.
    //
    // `average_rating`, `total_jobs_completed`, and
    // `response_time_avg_minutes` are server-computed fields and are
    // intentionally excluded — sending them would overwrite server data
    // with client-default zero values on every save.
    'id': userId,
    'headline': headline,
    'bio': bio,
    'years_experience': yearsExperience,
    'hourly_rate_pkr': hourlyRatePkr,
    'fixed_rate_note': fixedRateNote,
    'availability_status': availabilityStatus.name,
    'service_radius_km': serviceRadiusKm,
    'portfolio_media': portfolioMediaUrls,
    // 'is_featured' is intentionally excluded — it is an admin-managed flag
    // that should never be overwritten by client-side profile saves.
  };

  /// Display a star rating string (e.g. "4.5 ⭐")
  String get ratingDisplay {
    if (averageRating == 0) return 'No ratings yet';
    return '${averageRating.toStringAsFixed(1)} ⭐';
  }
}

enum AvailabilityStatus {
  today,
  tomorrow,
  weekdays,
  weekends,
  morning,
  evening,
  busy,
  offline;

  String get label {
    switch (this) {
      case AvailabilityStatus.today:
        return 'Today';
      case AvailabilityStatus.tomorrow:
        return 'Tomorrow';
      case AvailabilityStatus.weekdays:
        return 'Weekdays';
      case AvailabilityStatus.weekends:
        return 'Weekends';
      case AvailabilityStatus.morning:
        return 'Morning';
      case AvailabilityStatus.evening:
        return 'Evening';
      case AvailabilityStatus.busy:
        return 'Busy';
      case AvailabilityStatus.offline:
        return 'Offline';
    }
  }

  IconData get icon {
    switch (this) {
      case AvailabilityStatus.today:
        return Icons.today_rounded;
      case AvailabilityStatus.tomorrow:
        return Icons.event_rounded;
      case AvailabilityStatus.weekdays:
        return Icons.calendar_view_week_rounded;
      case AvailabilityStatus.weekends:
        return Icons.calendar_view_month_rounded;
      case AvailabilityStatus.morning:
        return Icons.wb_sunny_rounded;
      case AvailabilityStatus.evening:
        return Icons.nightlight_round;
      case AvailabilityStatus.busy:
        return Icons.work_off_rounded;
      case AvailabilityStatus.offline:
        return Icons.cloud_off_rounded;
    }
  }
}

/// All available categories for workers to select
const List<String> allWorkerCategories = [
  'Plumbing',
  'Electrical',
  'Painting',
  'Carpentry',
  'Masonry',
  'Mechanic',
  'Bike Repair',
  'Car Wash',
  'Labor',
  'Welding',
  'Steel Fixing',
  'Tutor',
  'Language Teacher',
  'Laptop Repair',
  'Mobile Repair',
  'Web Developer',
  'Photographer',
  'DJ',
  'Cook',
  'Cleaning',
  'Moving',
  'Healthcare',
  'Beauty',
  'Pet Care',
  'General Labor',
];
