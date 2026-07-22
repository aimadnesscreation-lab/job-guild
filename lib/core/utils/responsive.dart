import 'package:flutter/material.dart';

/// Breakpoint thresholds for responsive layout adaptation.
class Breakpoints {
  Breakpoints._();

  /// Phone-portrait (< 600dp) — single-column layouts.
  static const double phone = 600;

  /// Tablet-portrait (600–1200dp) — two-column / wider cards.
  static const double tablet = 840;

  /// Desktop (≥ 1200dp) — multi-column grids, max-width containers.
  static const double desktop = 1200;

  /// Helper: true when screen is at least tablet width.
  static bool isTablet(double width) => width >= phone;

  /// Helper: true when screen is at least desktop width.
  static bool isDesktop(double width) => width >= desktop;

  /// Returns the number of cross-axis items for a grid based on width.
  static int gridColumns(double width) {
    if (width >= desktop) return 4;
    if (width >= tablet) return 3;
    return 2;
  }

  /// Returns the number of stats columns for a dashboard row based on width.
  static int statsColumns(double width) {
    if (width >= desktop) return 4;
    if (width >= phone) return 3;
    return 2;
  }

  /// Returns horizontal padding based on screen width.
  static EdgeInsets horizontalPadding(double width) {
    if (width >= desktop) return const EdgeInsets.symmetric(horizontal: 48);
    if (width >= tablet) return const EdgeInsets.symmetric(horizontal: 32);
    return const EdgeInsets.symmetric(horizontal: 16);
  }
}

/// A responsive builder that provides the current screen-width breakpoint
/// context. Use this instead of raw `MediaQuery.of(context).size.width`
/// when you need to adapt layout across phone/tablet/desktop.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, double width, bool isTablet)
  builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return builder(context, width, Breakpoints.isTablet(width));
  }
}

/// A responsive horizontal padding widget.
class ResponsivePadding extends StatelessWidget {
  final Widget child;

  const ResponsivePadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Padding(padding: Breakpoints.horizontalPadding(width), child: child);
  }
}

/// A container that constrains its child to a maximum readable width
/// (typically 720dp) and centers it on wider screens.
/// Useful for chat views and long-form content on tablets/desktop.
class ReadableContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ReadableContainer({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
