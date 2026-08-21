import 'dart:math';
import 'package:flutter/material.dart';
import '../core/utils/attendance_math.dart';

class AttendanceRing extends StatefulWidget {
  final double percentage;
  final AttendanceStatus status;
  final double size;
  final double strokeWidth;

  const AttendanceRing({
    super.key,
    required this.percentage,
    required this.status,
    this.size = 180.0,
    this.strokeWidth = 14.0,
  });

  @override
  State<AttendanceRing> createState() => _AttendanceRingState();
}

class _AttendanceRingState extends State<AttendanceRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.percentage,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AttendanceRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _animation =
          Tween<double>(
            begin: oldWidget.percentage,
            end: widget.percentage,
          ).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color statusColor = AttendanceMath.getStatusColor(widget.status);
    final String label = AttendanceMath.getStatusLabel(widget.status);

    // Dynamic gradient colors
    List<Color> gradientColors;
    switch (widget.status) {
      case AttendanceStatus.danger:
        gradientColors = [const Color(0xFFBA1A1A), const Color(0xFFFD56A7)];
        break;
      case AttendanceStatus.warning:
        gradientColors = [const Color(0xFFEAB308), const Color(0xFFF59E0B)];
        break;
      case AttendanceStatus.safe:
        gradientColors = [const Color(0xFF22C55E), const Color(0xFF16A34A)];
        break;
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingPainter(
                  percentage: _animation.value,
                  gradientColors: gradientColors,
                  strokeWidth: widget.strokeWidth,
                  trackColor: isDark
                      ? const Color(0xFF2D3133)
                      : const Color(0xFFE0E3E5),
                ),
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.percentage.toStringAsFixed(2)}%',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: widget.size * 0.16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.5,
                  fontSize: widget.size * 0.06,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percentage;
  final List<Color> gradientColors;
  final double strokeWidth;
  final Color trackColor;

  _RingPainter({
    required this.percentage,
    required this.gradientColors,
    required this.strokeWidth,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw background track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    if (percentage <= 0) return;

    // Draw active progress ring with sweep gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final startAngle = -pi / 2;
    final sweepAngle = (percentage / 100) * 2 * pi;

    final progressPaint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: gradientColors,
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
      ).createShader(rect);

    // Rotate canvas slightly to align sweep gradient start with startAngle
    canvas.save();
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.gradientColors != gradientColors;
  }
}
