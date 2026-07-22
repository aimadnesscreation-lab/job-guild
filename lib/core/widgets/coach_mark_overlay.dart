import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/localization/strings.dart';
import 'package:local_services_marketplace/core/providers/tutorial_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';

/// A step in the coach marks tutorial
class _CoachStep {
  final int targetTabIndex;
  final String title;
  final String description;

  const _CoachStep({
    required this.targetTabIndex,
    required this.title,
    required this.description,
  });
}

/// Full-screen overlay showing coach marks that highlight navigation tabs
/// with animated tooltips. Steps: Search (1) → Post Job (2) → Messages (3).
/// Dismiss by tapping "Skip" or completing all steps.
class CoachMarkOverlay extends ConsumerStatefulWidget {
  /// The total width of the bottom navigation bar.
  final double bottomNavWidth;

  /// The height of the bottom navigation bar.
  final double bottomNavHeight;

  const CoachMarkOverlay({
    super.key,
    required this.bottomNavWidth,
    required this.bottomNavHeight,
  });

  @override
  ConsumerState<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends ConsumerState<CoachMarkOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  List<_CoachStep> _buildSteps(AppStrings s) => [
    _CoachStep(
      targetTabIndex: 1,
      title: s.tutorialTabSearchTitle,
      description: s.tutorialTabSearchDesc,
    ),
    _CoachStep(
      targetTabIndex: 2,
      title: s.tutorialTabPostTitle,
      description: s.tutorialTabPostDesc,
    ),
    _CoachStep(
      targetTabIndex: 3,
      title: s.tutorialTabChatTitle,
      description: s.tutorialTabChatDesc,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    // Start the first step with animation after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _nextStep() {
    final totalSteps = _buildSteps(ref.read(appStringsProvider)).length;
    if (_currentStep < totalSteps - 1) {
      _animController.reverse().then((_) {
        if (!context.mounted) return;
        setState(() => _currentStep++);
        _animController.forward();
      });
    } else {
      _dismiss();
    }
  }

  void _dismiss() {
    ref.read(tutorialCompletedProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final steps = _buildSteps(s);
    final step = steps[_currentStep];
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // Calculate the highlight position for the target tab.
    // Bottom nav has 5 items evenly spaced.
    final tabWidth = widget.bottomNavWidth / 5;
    final highlightCenterX = (step.targetTabIndex * tabWidth) + (tabWidth / 2);
    final navY = screenHeight - widget.bottomNavHeight;
    final highlightRadius = tabWidth * 0.45;

    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        onTap: _nextStep,
        child: Stack(
          children: [
            // ─── Semi-transparent overlay with hole punch ────
            CustomPaint(
              size: Size(screenWidth, screenHeight),
              painter: _CoachMarkPainter(
                highlightCenter: Offset(
                  highlightCenterX,
                  navY + widget.bottomNavHeight / 2,
                ),
                highlightRadius: highlightRadius,
                overlayColor: Colors.black.withValues(alpha: 0.55),
              ),
            ),

            // ─── Tooltip card ───────────────────────────────
            Positioned(
              left: 16,
              right: 16,
              bottom: widget.bottomNavHeight + 24,
              child: SlideTransition(
                position: _slideAnim,
                child: Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step counter + Skip
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_currentStep + 1}/${steps.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _dismiss,
                              child: Text(
                                s.tutorialSkip,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Title
                        Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Description
                        Text(
                          step.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Next / Got it button
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _nextStep,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              _currentStep < steps.length - 1
                                  ? s.tutorialNext
                                  : s.tutorialDone,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ─── Arrow pointing down to the tab ────────────
            Positioned(
              left: highlightCenterX - 12,
              bottom: widget.bottomNavHeight + 8,
              child: IgnorePointer(
                child: SlideTransition(
                  position: _slideAnim,
                  child: const Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that draws a semi-transparent overlay with a circular
/// cutout (hole punch) at the highlight position.
class _CoachMarkPainter extends CustomPainter {
  final Offset highlightCenter;
  final double highlightRadius;
  final Color overlayColor;

  _CoachMarkPainter({
    required this.highlightCenter,
    required this.highlightRadius,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = overlayColor;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(
        Rect.fromCircle(center: highlightCenter, radius: highlightRadius + 6),
      );

    // Use even-odd fill to create the hole punch. The rect and oval are
    // both added to the same path; the even-odd fill rule leaves the oval
    // transparent while painting everything else.
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Glowing ring around the highlight
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(highlightCenter, highlightRadius + 8, ringPaint);
  }

  @override
  bool shouldRepaint(_CoachMarkPainter oldDelegate) =>
      oldDelegate.highlightCenter != highlightCenter ||
      oldDelegate.highlightRadius != highlightRadius;
}
