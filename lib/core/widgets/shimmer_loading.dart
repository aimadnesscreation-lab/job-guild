import 'package:flutter/material.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';

/// A shimmer placeholder effect for loading states.
/// Mimics the shape and size of real content while data loads.
class ShimmerWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                AppTheme.surfaceColor,
                AppTheme.surfaceColor.withValues(alpha: 0.5),
                AppTheme.surfaceColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// A card-shaped skeleton loader for job cards in the feed
class JobCardShimmer extends StatelessWidget {
  const JobCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerWidget(width: 60, height: 18),
                const Spacer(),
                const ShimmerWidget(width: 50, height: 12),
              ],
            ),
            const SizedBox(height: 12),
            const ShimmerWidget(width: double.infinity, height: 18),
            const SizedBox(height: 8),
            const ShimmerWidget(width: 200, height: 14),
            const SizedBox(height: 12),
            Row(
              children: [
                const ShimmerWidget(width: 80, height: 16),
                const Spacer(),
                const ShimmerWidget(width: 60, height: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton loader for worker result cards
class WorkerCardShimmer extends StatelessWidget {
  const WorkerCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const ShimmerWidget(width: 52, height: 52, borderRadius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerWidget(width: 120, height: 16),
                  const SizedBox(height: 8),
                  const ShimmerWidget(width: double.infinity, height: 14),
                  const SizedBox(height: 4),
                  const ShimmerWidget(width: 140, height: 12),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Column(
              children: [
                ShimmerWidget(width: 50, height: 14),
                SizedBox(height: 8),
                ShimmerWidget(width: 60, height: 28, borderRadius: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A list of shimmer cards for the job feed loading state
class JobFeedShimmer extends StatelessWidget {
  const JobFeedShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        JobCardShimmer(),
        JobCardShimmer(),
        JobCardShimmer(),
        JobCardShimmer(),
      ],
    );
  }
}

/// A list of shimmer cards for the worker search loading state
class WorkerSearchShimmer extends StatelessWidget {
  const WorkerSearchShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [WorkerCardShimmer(), WorkerCardShimmer(), WorkerCardShimmer()],
    );
  }
}
