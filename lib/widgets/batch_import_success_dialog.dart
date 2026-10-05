import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BatchImportSuccessDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final int subjectCount;
  final int slotCount;
  final VoidCallback? onDone;

  const BatchImportSuccessDialog({
    super.key,
    this.title = 'Batch Joined Successfully!',
    this.subtitle =
        'Your course tracker and timetable are now synced with this batch.',
    required this.subjectCount,
    required this.slotCount,
    this.onDone,
  });

  static Future<void> show({
    required BuildContext context,
    String title = 'Batch Joined Successfully!',
    String subtitle =
        'Your course tracker and timetable are now synced with this batch.',
    required int subjectCount,
    required int slotCount,
    VoidCallback? onDone,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => BatchImportSuccessDialog(
        title: title,
        subtitle: subtitle,
        subjectCount: subjectCount,
        slotCount: slotCount,
        onDone: onDone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2124) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Success check circle with soft halo
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ).animate().scale(
                      duration: 400.ms,
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 20),

                // 2. Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    fontFamily: 'Inter',
                  ),
                ),

                const SizedBox(height: 8),

                // 3. Subtitle
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                    fontFamily: 'Inter',
                  ),
                ),

                const SizedBox(height: 20),

                // 4. Summary Stats Box
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF282C2F)
                        : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE5E7EB),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Left: Subjects stat
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_stories_outlined,
                                  size: 18,
                                  color: Color(0xFF6366F1),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$subjectCount',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$subjectCount new subjects',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Vertical Divider
                      Container(
                        width: 1,
                        height: 36,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFE5E7EB),
                      ),

                      // Right: Slots stat
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 18,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$slotCount',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Timetable slots',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 5. Done Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDone?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).scale(
          begin: const Offset(0.92, 0.92),
          end: const Offset(1.0, 1.0),
          duration: 250.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
