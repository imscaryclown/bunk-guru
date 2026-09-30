import 'package:flutter/material.dart';

enum AttendanceStatus { safe, warning, danger }

class AttendanceMath {
  static const double threshold = 0.75;

  static double currentPercent(int attended, int total) {
    if (total <= 0) return 0.0;
    return (attended / total) * 100;
  }

  // Max classes you can skip while staying >= 75%
  static int safeBunks(int attended, int total) {
    if (total <= 0) return 0;
    final double x = (attended - threshold * total) / threshold;
    final int result = x.floor();
    return result < 0 ? 0 : result;
  }

  // Min classes to attend to reach 75%
  static int requiredClasses(int attended, int total) {
    if (total <= 0) return 0;
    final double pct = attended / total;
    if (pct >= threshold) return 0;
    final double y = (threshold * total - attended) / (1 - threshold);
    final int result = y.ceil();
    return result < 0 ? 0 : result;
  }

  // Status: 'safe' (>=75%), 'danger' (<75%)
  static AttendanceStatus getStatus(int attended, int total) {
    if (total <= 0) return AttendanceStatus.safe;
    final double pct = (attended / total) * 100;
    if (pct >= 75.0) return AttendanceStatus.safe;
    return AttendanceStatus.danger;
  }

  static String getStatusLabel(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.safe:
      case AttendanceStatus.warning:
        return 'ON TRACK';
      case AttendanceStatus.danger:
        return 'DANGER ZONE';
    }
  }

  static String getStatusMessage(int attended, int total) {
    final AttendanceStatus status = getStatus(attended, total);
    if (status == AttendanceStatus.safe || status == AttendanceStatus.warning) {
      final int bunks = safeBunks(attended, total);
      return 'You can skip $bunks class${bunks != 1 ? 'es' : ''} safely';
    }
    final int needed = requiredClasses(attended, total);
    return 'Attend next $needed class${needed != 1 ? 'es' : ''} to reach 75%';
  }

  static Color getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.safe:
      case AttendanceStatus.warning:
        return const Color(0xFF22C55E); // Green
      case AttendanceStatus.danger:
        return const Color(0xFFDC2626); // Red
    }
  }

  static IconData getStatusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.safe:
      case AttendanceStatus.warning:
        return Icons.check_circle;
      case AttendanceStatus.danger:
        return Icons.error;
    }
  }
}
