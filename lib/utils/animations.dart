import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

extension DurationExtension on int {
  Duration get ms => Duration(milliseconds: this);
}

extension AnimationExtensions on Widget {
  Widget fadeInSlideUp({
    Duration delay = const Duration(milliseconds: 0),
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return animate(
      delay: delay,
      effects: [
        FadeEffect(duration: duration),
        SlideEffect(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
          duration: duration,
          curve: Curves.easeOut,
        ),
      ],
    );
  }

  Widget fadeIn({
    Duration delay = const Duration(milliseconds: 0),
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return animate(delay: delay, effects: [FadeEffect(duration: duration)]);
  }

  Widget slideInLeft({
    Duration delay = const Duration(milliseconds: 0),
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return animate(
      delay: delay,
      effects: [
        SlideEffect(
          begin: const Offset(-0.2, 0),
          end: Offset.zero,
          duration: duration,
          curve: Curves.easeOut,
        ),
        FadeEffect(duration: duration),
      ],
    );
  }

  Widget slideInRight({
    Duration delay = const Duration(milliseconds: 0),
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return animate(
      delay: delay,
      effects: [
        SlideEffect(
          begin: const Offset(0.2, 0),
          end: Offset.zero,
          duration: duration,
          curve: Curves.easeOut,
        ),
        FadeEffect(duration: duration),
      ],
    );
  }

  Widget scaleIn({
    Duration delay = const Duration(milliseconds: 0),
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return animate(
      delay: delay,
      effects: [
        ScaleEffect(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          duration: duration,
          curve: Curves.easeOut,
        ),
        FadeEffect(duration: duration),
      ],
    );
  }
}

class StaggeredListAnimation extends StatelessWidget {
  final List<Widget> children;
  final Duration staggerDelay;

  const StaggeredListAnimation({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 100),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          children.asMap().entries.map((entry) {
            final index = entry.key;
            final child = entry.value;
            return child.fadeInSlideUp(delay: staggerDelay * index);
          }).toList(),
    );
  }
}
