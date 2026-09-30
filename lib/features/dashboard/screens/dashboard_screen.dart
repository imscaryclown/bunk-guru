import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/attendance_math.dart';
import '../../../core/utils/time_formatter.dart';
import 'package:flutter/services.dart';
import '../../../widgets/attendance_ring.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/bunk_app_bar.dart';
import '../../../services/providers.dart';
import '../../../models/subject.dart';
import '../../../models/schedule_slot.dart';
import '../../../services/supabase_service.dart';
import '../../profile/screens/profile_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final Map<String, int> _promptSteps = {};

  void _toast(String msg, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: isSuccess
            ? const Color(0xFF16A34A)
            : AppColors.primaryContainer,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final profile = ref.watch(profileProvider);
    final subjects = ref.watch(subjectProvider);
    final schedule = ref.watch(scheduleProvider);
    final responses = ref.watch(responseProvider);
    final isSyncing = ref.watch(syncProvider);

    if (subjects.isEmpty && isSyncing) {
      return _buildSkeleton(context);
    }

    int totalClasses = 0;
    int attendedClasses = 0;
    for (final s in subjects) {
      totalClasses += s.totalClasses + s.practicalTotal;
      attendedClasses += s.attendedClasses + s.practicalAttended;
    }
    final double percentage = AttendanceMath.currentPercent(
      attendedClasses,
      totalClasses,
    );
    final AttendanceStatus overallStatus = AttendanceMath.getStatus(
      attendedClasses,
      totalClasses,
    );
    final int needed = AttendanceMath.requiredClasses(
      attendedClasses,
      totalClasses,
    );
    final int canSkip = AttendanceMath.safeBunks(attendedClasses, totalClasses);

    final String initial = profile?.displayName.isNotEmpty == true
        ? profile!.displayName[0]
        : 'S';
    final Widget avatar = GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(tabIndexProvider.notifier).state = 4;
      },
      child: profile?.avatarUrl.isNotEmpty == true
          ? CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(profile!.avatarUrl),
            )
          : CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );

    final now = DateTime.now();
    final todayDay = (now.weekday - 1);
    final int nowMinutes = now.hour * 60 + now.minute;
    final String todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final todayResponses = responses[todayKey] ?? {};

    final List<ScheduleSlot> pendingSlots = schedule.where((slot) {
      if (slot.dayOfWeek != todayDay) return false;
      final timeParts = slot.time.split(':').map(int.parse).toList();
      if (timeParts.length < 2) return false;
      final int slotMinutes = timeParts[0] * 60 + timeParts[1];
      if (nowMinutes < slotMinutes) return false;
      if (todayResponses.containsKey(slot.id)) return false;

      // Filter out slots that were created or imported after the class start time today
      try {
        final DateTime slotCreated = DateTime.parse(slot.createdAt);
        final DateTime slotOccurredToday = DateTime(
          now.year,
          now.month,
          now.day,
          timeParts[0],
          timeParts[1],
        );
        if (slotCreated.isAfter(slotOccurredToday)) {
          return false;
        }
      } catch (_) {}

      return subjects.any((s) => s.id == slot.subjectId);
    }).toList();

    final List<ScheduleSlot> todaySlots = schedule
        .where((s) => s.dayOfWeek == todayDay)
        .toList();
    todaySlots.sort((a, b) => a.time.compareTo(b.time));

    return Scaffold(
      appBar: BunkAppBar(
        leading: avatar,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primaryLight,
            ),
            tooltip: 'Notification Settings',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const NotificationPrefsSheet(),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            try {
              await SupabaseService.syncFromCloud(true);
              ref.read(profileProvider.notifier).refresh();
              ref.read(subjectProvider.notifier).refresh();
              ref.read(scheduleProvider.notifier).refresh();
              ref.read(responseProvider.notifier).refresh();
            } catch (_) {}
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            children: [
              if (pendingSlots.isNotEmpty) ...[
                _buildPendingPromptsSection(pendingSlots, subjects),
                const SizedBox(height: 24),
              ],
              _buildMainAttendanceCard(
                percentage,
                overallStatus,
                totalClasses,
                attendedClasses,
                needed,
                canSkip,
              ),
              const SizedBox(height: 24),
              _buildTodayScheduleSection(todaySlots, subjects, nowMinutes),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainAttendanceCard(
    double percentage,
    AttendanceStatus status,
    int total,
    int attended,
    int needed,
    int canSkip,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : AppColors.bgSurfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.outlineVariantLight.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(
                        alpha: isDark ? 0.1 : 0.05,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: (percentage < 75.0 && total > 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF16A34A))
                          .withValues(
                        alpha: isDark ? 0.1 : 0.05,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              AttendanceRing(
                percentage: percentage,
                status: status,
                size: 160,
                strokeWidth: 12,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildMiniStatBox('TOTAL', total.toString(), null),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatBox(
                  'ATTENDED',
                  attended.toString(),
                  const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatBox(
                  'MISSED',
                  (total - attended).toString(),
                  AppColors.redBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (percentage < 75.0 && total > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.redBg.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.redBg, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Attend next $needed classes safely',
                      style: const TextStyle(
                        color: AppColors.onErrorContainer,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (canSkip >= 0 && total > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                    : const Color(0xFFF0FDF4).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                      : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                      weight: 700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can skip $canSkip classes safely',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFF166534),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStatBox(String label, String value, Color? highlightColor) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.bgSurfaceLowLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.outlineVariantLight.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlightColor ?? AppColors.outlineLight,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: highlightColor ?? (isDark ? Colors.white : Colors.black),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayScheduleSection(
    List<ScheduleSlot> todaySlots,
    List<Subject> subjects,
    int nowMinutes,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final List<String> monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Schedule",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(tabIndexProvider.notifier).state = 2;
              },
              child: const Text(
                "Full Week",
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (todaySlots.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : AppColors.bgSurfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.outlineVariantLight.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D3133) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : AppColors.outlineVariantLight.withValues(
                              alpha: 0.2,
                            ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        color: AppColors.redBg,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          monthNames[now.month - 1].toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${now.day}',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Classes Today',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enjoy your free day!',
                  style: TextStyle(color: AppColors.outlineLight, fontSize: 14),
                ),
              ],
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 340),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: todaySlots.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final slot = todaySlots[index];
                final subject = subjects.firstWhere(
                  (s) => s.id == slot.subjectId,
                  orElse: () => Subject(
                    id: '',
                    userId: '',
                    name: 'Unknown Subject',
                    createdAt: now.toIso8601String(),
                  ),
                );

                final timeParts = slot.time.split(':').map(int.parse).toList();
                final startTotal = timeParts.length >= 2
                    ? timeParts[0] * 60 + timeParts[1]
                    : 0;
                final endTotal = slot.endTime.isNotEmpty
                    ? (() {
                        final eParts = slot.endTime
                            .split(':')
                            .map(int.parse)
                            .toList();
                        return eParts.length >= 2
                            ? eParts[0] * 60 + eParts[1]
                            : startTotal + 50;
                      })()
                    : startTotal + 50;

                final bool hasPassed = nowMinutes > endTotal;
                final bool isOngoing =
                    nowMinutes >= startTotal && nowMinutes <= endTotal;

                final colors = [
                  AppColors.primaryLight,
                  AppColors.secondaryLight,
                  const Color(0xFF006A7C),
                ];
                final color = colors[index % colors.length];

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(tabIndexProvider.notifier).state = 2;
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : AppColors.bgSurfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isOngoing
                            ? AppColors.primaryLight.withValues(alpha: 0.3)
                            : (hasPassed
                                  ? AppColors.outlineVariantLight.withValues(
                                      alpha: 0.5,
                                    )
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : AppColors.outlineVariantLight
                                              .withValues(alpha: 0.2))),
                      ),
                      boxShadow: isOngoing
                          ? [
                              BoxShadow(
                                color: AppColors.primaryLight.withValues(
                                  alpha: 0.12,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    foregroundDecoration: hasPassed
                        ? BoxDecoration(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.6),
                            backgroundBlendMode: BlendMode.saturation,
                          )
                        : null,
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            color: hasPassed
                                ? AppColors.outlineVariantLight
                                : color,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: hasPassed
                                          ? AppColors.outlineVariantLight
                                                .withValues(alpha: 0.3)
                                          : color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getIconData(subject.icon),
                                      color: hasPassed
                                          ? AppColors.outlineLight
                                          : color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          subject.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              size: 12,
                                              color: AppColors.outlineLight,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              slot.room.isNotEmpty
                                                  ? slot.room
                                                  : 'TBD',
                                              style: const TextStyle(
                                                color: AppColors.outlineLight,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 4,
                                              ),
                                              child: Text(
                                                '•',
                                                style: TextStyle(
                                                  color: AppColors.outlineLight,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              slot.slotType == 'practical'
                                                  ? 'Practical'
                                                  : 'Theory',
                                              style: TextStyle(
                                                color: AppColors.primaryLight,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        TimeFormatter.formatTime(slot.time),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (slot.endTime.isNotEmpty)
                                        Text(
                                          'to ${TimeFormatter.formatTime(slot.endTime)}',
                                          style: const TextStyle(
                                            color: AppColors.outlineLight,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      if (hasPassed)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.done,
                                                size: 10,
                                                color: AppColors.outlineLight,
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                'Ended',
                                                style: TextStyle(
                                                  color: AppColors.outlineLight,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (isOngoing)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: AppColors
                                                              .primaryLight,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                  )
                                                  .animate(
                                                    onPlay: (controller) =>
                                                        controller.repeat(
                                                          reverse: true,
                                                        ),
                                                  )
                                                  .fade(
                                                    begin: 0.3,
                                                    end: 1.0,
                                                    duration: 800.ms,
                                                  ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'Ongoing',
                                                style: TextStyle(
                                                  color: AppColors.primaryLight,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/calculator'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : AppColors.bgSurfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppColors.outlineVariantLight.withValues(
                              alpha: 0.3,
                            ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.calculate,
                        color: AppColors.primaryLight,
                        size: 28,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bunk Calculator',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'WHAT-IF SIMULATOR',
                        style: TextStyle(
                          color: AppColors.outlineLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(tabIndexProvider.notifier).state = 3;
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : AppColors.bgSurfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppColors.outlineVariantLight.withValues(
                              alpha: 0.3,
                            ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.analytics,
                        color: AppColors.secondaryLight,
                        size: 28,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'View History',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ACTIVITY TIMELINE',
                        style: TextStyle(
                          color: AppColors.outlineLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Pending Prompts builder
  Widget _buildPendingPromptsSection(
    List<ScheduleSlot> pending,
    List<Subject> subjects,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.notifications_active,
              color: AppColors.primaryLight,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Pending Check-ins',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${pending.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...pending.map((slot) {
          final subject = subjects.firstWhere(
            (s) => s.id == slot.subjectId,
            orElse: () => Subject(
              id: '',
              userId: '',
              name: 'Unknown',
              createdAt: DateTime.now().toIso8601String(),
            ),
          );
          final step = _promptSteps[slot.id] ?? 1;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF242729)
                  : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryLight.withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryLight.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getIconData(subject.icon),
                          color: AppColors.primaryLight,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: AppColors.outlineLight,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  TimeFormatter.formatTime(slot.time) +
                                      (slot.room.isNotEmpty
                                          ? ' · ${slot.room}'
                                          : ''),
                                  style: const TextStyle(
                                    color: AppColors.outlineLight,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  color: AppColors.outlineLight.withValues(alpha: 0.1),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: step == 1
                      ? _buildPromptStep1(slot.id)
                      : _buildPromptStep2(slot.id),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPromptStep1(String slotId) {
    return Padding(
      key: const ValueKey('step1'),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          const Text(
            'Did this lecture happen?',
            style: TextStyle(color: AppColors.outlineLight, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppColors.bgSurfaceContainerLight,
                  borderRadius: 10,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onTap: () async {
                    await ref
                        .read(responseProvider.notifier)
                        .respond(
                          slotId: slotId,
                          lectureHappened: false,
                          attended: false,
                        );
                    _toast('Lecture recorded as Cancelled ❌', false);
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Cancelled',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomButton(
                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                  borderRadius: 10,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onTap: () {
                    setState(() {
                      _promptSteps[slotId] = 2;
                    });
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check,
                        color: AppColors.primaryLight,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Yes, it did',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromptStep2(String slotId) {
    return Padding(
      key: const ValueKey('step2'),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          const Text(
            'Did you attend it?',
            style: TextStyle(color: AppColors.outlineLight, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  color: AppColors.redBg.withValues(alpha: 0.1),
                  borderRadius: 10,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onTap: () async {
                    await ref
                        .read(responseProvider.notifier)
                        .respond(
                          slotId: slotId,
                          lectureHappened: true,
                          attended: false,
                        );
                    _toast('Bunked! 😎 Stay above 75%!', false);
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flight_takeoff,
                        color: AppColors.redBg,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Bunked 😎',
                        style: TextStyle(
                          color: AppColors.redBg,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomButton(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  borderRadius: 10,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onTap: () async {
                    await ref
                        .read(responseProvider.notifier)
                        .respond(
                          slotId: slotId,
                          lectureHappened: true,
                          attended: true,
                        );
                    _toast('Attendance recorded! 🎓', true);
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Color(0xFF16A34A),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Attended ✅',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'account_tree':
        return Icons.account_tree;
      case 'calculate':
        return Icons.calculate;
      case 'computer':
        return Icons.computer;
      case 'science':
        return Icons.science;
      case 'code':
        return Icons.code;
      case 'school':
      default:
        return Icons.school;
    }
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        leadingWidth: 48,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle),
          ),
        ),
        title: Container(
          width: 140,
          height: 24,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        actions: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.indigo.withValues(alpha: 0.05),
            height: 1.0,
          ),
        ),
      ),
      body:
          SafeArea(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 16.0,
                  ),
                  children: [
                    // Main Attendance Card Skeleton
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              color: highlightColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: highlightColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: highlightColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: highlightColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Today's Schedule Skeleton
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 120,
                          height: 20,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 16,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Quick Actions Skeleton
                    Container(
                      width: 100,
                      height: 20,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: baseColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(
                duration: 1500.ms,
                color: isDark ? Colors.white24 : Colors.black12,
              ),
    );
  }
}
