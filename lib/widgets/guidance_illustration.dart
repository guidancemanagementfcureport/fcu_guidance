import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../utils/animations.dart';

/// A custom, modern illustration widget representing student guidance and support.
/// Features a counselor/teacher assisting a student in a digital-first environment.
class GuidanceIllustration extends StatefulWidget {
  final double? width;
  final double? height;
  final bool enableAnimation;

  const GuidanceIllustration({
    super.key,
    this.width,
    this.height,
    this.enableAnimation = true,
  });

  @override
  State<GuidanceIllustration> createState() => _GuidanceIllustrationState();
}

class _GuidanceIllustrationState extends State<GuidanceIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final defaultWidth = widget.width ?? math.min(size.width * 0.9, 500);
    final defaultHeight = widget.height ?? defaultWidth * 0.8;

    return Semantics(
      label: 'Illustration showing a counselor providing guidance and support to a student',
      child: SizedBox(
        width: defaultWidth,
        height: defaultHeight,
        child: widget.enableAnimation
            ? AnimatedBuilder(
                animation: _floatAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatAnimation.value),
                    child: CustomPaint(
                      size: Size(defaultWidth, defaultHeight),
                      painter: _GuidanceIllustrationPainter(),
                    ),
                  );
                },
              )
            : CustomPaint(
                size: Size(defaultWidth, defaultHeight),
                painter: _GuidanceIllustrationPainter(),
              ),
      ),
    ).fadeIn(delay: 300.ms);
  }
}

class _GuidanceIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Scale factor for responsive sizing
    final scale = size.width / 500;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Background circle (soft glow)
    paint.color = AppTheme.skyBlue.withValues(alpha: 0.1);
    canvas.drawCircle(
      Offset(centerX, centerY + 20 * scale),
      size.width * 0.45,
      paint,
    );

    // Counselor/Teacher figure (left side)
    _drawPerson(
      canvas,
      Offset(centerX - 120 * scale, centerY + 40 * scale),
      scale,
      isCounselor: true,
    );

    // Student figure (right side)
    _drawPerson(
      canvas,
      Offset(centerX + 120 * scale, centerY + 40 * scale),
      scale,
      isCounselor: false,
    );

    // Digital device (laptop/tablet) between them
    _drawDevice(
      canvas,
      Offset(centerX, centerY + 60 * scale),
      scale,
    );

    // Support elements (floating icons)
    _drawSupportElements(canvas, size, scale);
  }

  void _drawPerson(Canvas canvas, Offset position, double scale,
      {required bool isCounselor}) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Head (rounded, minimal features)
    paint.color = const Color(0xFFFFE5D4); // Soft skin tone
    canvas.drawCircle(position, 25 * scale, paint);

    // Body (rounded rectangle for torso)
    paint.color = isCounselor ? AppTheme.mediumBlue : AppTheme.skyBlue;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(position.dx, position.dy + 50 * scale),
        width: 60 * scale,
        height: 80 * scale,
      ),
      Radius.circular(30 * scale),
    );
    canvas.drawRRect(bodyRect, paint);

    // Arms (simple rounded rectangles)
    paint.color = const Color(0xFFFFE5D4);
    // Left arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(position.dx - 35 * scale, position.dy + 50 * scale),
          width: 20 * scale,
          height: 60 * scale,
        ),
        Radius.circular(10 * scale),
      ),
      paint,
    );
    // Right arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(position.dx + 35 * scale, position.dy + 50 * scale),
          width: 20 * scale,
          height: 60 * scale,
        ),
        Radius.circular(10 * scale),
      ),
      paint,
    );

    // Simple face (minimalist, inclusive)
    paint.color = AppTheme.darkGray.withValues(alpha: 0.3);
    // Eyes (small dots)
    canvas.drawCircle(
      Offset(position.dx - 8 * scale, position.dy - 5 * scale),
      3 * scale,
      paint,
    );
    canvas.drawCircle(
      Offset(position.dx + 8 * scale, position.dy - 5 * scale),
      3 * scale,
      paint,
    );
    // Smile (simple arc)
    final smilePath = Path()
      ..addArc(
        Rect.fromCenter(
          center: Offset(position.dx, position.dy + 5 * scale),
          width: 20 * scale,
          height: 10 * scale,
        ),
        0,
        math.pi,
      );
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2 * scale;
    canvas.drawPath(smilePath, paint);
    paint.style = PaintingStyle.fill;

    // Counselor badge/icon
    if (isCounselor) {
      paint.color = Colors.white;
      canvas.drawCircle(
        Offset(position.dx, position.dy + 50 * scale),
        12 * scale,
        paint,
      );
      paint.color = AppTheme.skyBlue;
      final iconPath = Path()
        ..addPolygon(
          [
            Offset(position.dx, position.dy + 45 * scale),
            Offset(position.dx - 6 * scale, position.dy + 52 * scale),
            Offset(position.dx + 6 * scale, position.dy + 52 * scale),
          ],
          true,
        );
      canvas.drawPath(iconPath, paint);
    }
  }

  void _drawDevice(Canvas canvas, Offset position, double scale) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Laptop/Tablet base
    paint.color = Colors.white;
    final deviceRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: position,
        width: 140 * scale,
        height: 100 * scale,
      ),
      Radius.circular(12 * scale),
    );
    canvas.drawRRect(deviceRect, paint);

    // Screen
    paint.color = AppTheme.paleBlue;
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(position.dx, position.dy - 5 * scale),
        width: 120 * scale,
        height: 80 * scale,
      ),
      Radius.circular(8 * scale),
    );
    canvas.drawRRect(screenRect, paint);

    // Screen content (simple dashboard representation)
    paint.color = AppTheme.skyBlue.withValues(alpha: 0.3);
    // Chart bars
    for (int i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            position.dx - 50 * scale + (i * 25 * scale),
            position.dy + 20 * scale,
            15 * scale,
            (20 + i * 5) * scale,
          ),
          Radius.circular(2 * scale),
        ),
        paint,
      );
    }

    // Shadow
    paint.color = Colors.black.withValues(alpha: 0.1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(position.dx, position.dy + 55 * scale),
          width: 140 * scale,
          height: 8 * scale,
        ),
        Radius.circular(4 * scale),
      ),
      paint,
    );
  }

  void _drawSupportElements(Canvas canvas, Size size, double scale) {
    final paint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..color = AppTheme.skyBlue.withValues(alpha: 0.3);

    // Floating support elements (shield, heart, checkmark circles)
    final elements = [
      {'type': 'shield', 'pos': Offset(size.width * 0.15, size.height * 0.2)},
      {'type': 'heart', 'pos': Offset(size.width * 0.85, size.height * 0.25)},
      {'type': 'check', 'pos': Offset(size.width * 0.1, size.height * 0.7)},
    ];

    for (final elementData in elements) {
      final pos = elementData['pos'] as Offset;
      final type = elementData['type'] as String;

      // Outer glow
      paint.color = AppTheme.skyBlue.withValues(alpha: 0.1);
      canvas.drawCircle(pos, 35 * scale, paint);

      // Inner circle
      paint.color = AppTheme.skyBlue.withValues(alpha: 0.2);
      canvas.drawCircle(pos, 28 * scale, paint);

      // Icon representation
      paint.color = AppTheme.skyBlue.withValues(alpha: 0.6);
      strokePaint.color = AppTheme.skyBlue.withValues(alpha: 0.6);

      switch (type) {
        case 'shield':
          // Shield shape
          final shieldPath = Path()
            ..moveTo(pos.dx, pos.dy - 15 * scale)
            ..lineTo(pos.dx - 10 * scale, pos.dy - 5 * scale)
            ..lineTo(pos.dx - 10 * scale, pos.dy + 5 * scale)
            ..lineTo(pos.dx, pos.dy + 15 * scale)
            ..lineTo(pos.dx + 10 * scale, pos.dy + 5 * scale)
            ..lineTo(pos.dx + 10 * scale, pos.dy - 5 * scale)
            ..close();
          canvas.drawPath(shieldPath, paint);
          break;
        case 'heart':
          // Heart shape
          final heartPath = Path()
            ..addArc(
              Rect.fromCenter(
                center: Offset(pos.dx - 6 * scale, pos.dy - 3 * scale),
                width: 12 * scale,
                height: 12 * scale,
              ),
              0,
              math.pi,
            )
            ..addArc(
              Rect.fromCenter(
                center: Offset(pos.dx + 6 * scale, pos.dy - 3 * scale),
                width: 12 * scale,
                height: 12 * scale,
              ),
              0,
              math.pi,
            )
            ..lineTo(pos.dx, pos.dy + 10 * scale)
            ..close();
          canvas.drawPath(heartPath, paint);
          break;
        case 'check':
          // Checkmark
          strokePaint.strokeWidth = 3 * scale;
          strokePaint.strokeCap = StrokeCap.round;
          strokePaint.strokeJoin = StrokeJoin.round;
          final checkPath = Path()
            ..moveTo(pos.dx - 8 * scale, pos.dy)
            ..lineTo(pos.dx - 2 * scale, pos.dy + 8 * scale)
            ..lineTo(pos.dx + 8 * scale, pos.dy - 6 * scale);
          canvas.drawPath(checkPath, strokePaint);
          break;
      }
    }

    // Connection lines (subtle)
    paint.color = AppTheme.skyBlue.withValues(alpha: 0.1);
    paint.strokeWidth = 1 * scale;
    paint.style = PaintingStyle.stroke;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(centerX - 120 * scale, centerY + 20 * scale),
      Offset(centerX + 120 * scale, centerY + 20 * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

