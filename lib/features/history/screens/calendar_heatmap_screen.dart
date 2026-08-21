import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/attendance_math.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../services/providers.dart';
import '../../../services/supabase_service.dart';
import '../../../models/subject.dart';
import '../../../models/schedule_slot.dart';
import '../../../models/attendance_response.dart';

import '../../../widgets/page_header.dart';
import '../../../widgets/header_icon_button.dart';

class CalendarHeatmapScreen extends ConsumerStatefulWidget {
  const CalendarHeatmapScreen({super.key});

  @override
  ConsumerState<CalendarHeatmapScreen> createState() =>
      _CalendarHeatmapScreenState();
}

class _CalendarHeatmapScreenState extends ConsumerState<CalendarHeatmapScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

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

  // Prepares history items (explicit logs + backfilled "Missed" entries for past 7 days)
  List<Map<String, dynamic>> _processHistory(
    Map<String, Map<String, AttendanceResponse>> allResponses,
    List<ScheduleSlot> allSlots,
    List<Subject> allSubjects,
  ) {
    final List<Map<String, dynamic>> items = [];

    // 1. Process explicit responses
    allResponses.forEach((dateKey, dayResponses) {
      dayResponses.forEach((slotId, response) {
        final slot = allSlots.firstWhere(
          (s) => s.id == slotId,
          orElse: () => ScheduleSlot(
            id: '',
            userId: '',
            subjectId: '',
            dayOfWeek: 0,
            createdAt: '',
          ),
        );
        if (slot.id.isNotEmpty) {
          final subject = allSubjects.firstWhere(
            (sub) => sub.id == slot.subjectId,
            orElse: () =>
                Subject(id: '', userId: '', name: 'Unknown', createdAt: ''),
          );
          if (subject.id.isNotEmpty) {
            items.add({
              'date': dateKey,
              'slotId': slotId,
              'response': response,
              'slot': slot,
              'subject': subject,
              'isMissed': false,
            });
          }
        }
      });
    });

    // 2. Add "Missed" entries for the past 7 days
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final targetDate = now.subtract(Duration(days: i));
      final dateKey =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      final int dayOfWeek = (targetDate.weekday - 1); // 0=Mon..6=Sun

      final daySlots = allSlots.where((s) => s.dayOfWeek == dayOfWeek).toList();
      for (final slot in daySlots) {
        final alreadyLogged =
            allResponses[dateKey]?.containsKey(slot.id) ?? false;
        if (!alreadyLogged) {
          final timeParts = slot.time.split(':').map(int.parse).toList();
          if (timeParts.length < 2) continue;

          final slotTime = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            timeParts[0],
            timeParts[1],
          );
          if (slotTime.isBefore(now)) {
            final subject = allSubjects.firstWhere(
              (sub) => sub.id == slot.subjectId,
              orElse: () =>
                  Subject(id: '', userId: '', name: 'Unknown', createdAt: ''),
            );
            if (subject.id.isNotEmpty) {
              final DateTime createdAt =
                  DateTime.tryParse(subject.createdAt) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              if (slotTime.isAfter(createdAt)) {
                items.add({
                  'date': dateKey,
                  'slotId': slot.id,
                  'response': AttendanceResponse(
                    id: '',
                    userId: '',
                    slotId: slot.id,
                    date: dateKey,
                    lectureHappened: true,
                    attended: false,
                    createdAt: '',
                  ),
                  'isMissed': true,
                  'slot': slot,
                  'subject': subject,
                });
              }
            }
          }
        }
      }
    }

    // Also include slots for the current month that are NOT missed (future or past unlogged, just to know there IS a class)
    // We do this by scanning days of current month
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    for (int i = 1; i <= daysInMonth; i++) {
      final targetDate = DateTime(_currentMonth.year, _currentMonth.month, i);
      final dateKey =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      final int dayOfWeek = (targetDate.weekday - 1); // 0=Mon..6=Sun

      final daySlots = allSlots.where((s) => s.dayOfWeek == dayOfWeek).toList();
      for (final slot in daySlots) {
        // If not already in items (not logged, not in 7 day missed window)
        final alreadyInItems = items.any(
          (item) => item['date'] == dateKey && item['slotId'] == slot.id,
        );
        if (!alreadyInItems) {
          final subject = allSubjects.firstWhere(
            (sub) => sub.id == slot.subjectId,
            orElse: () =>
                Subject(id: '', userId: '', name: 'Unknown', createdAt: ''),
          );
          if (subject.id.isNotEmpty) {
            final DateTime createdAt =
                DateTime.tryParse(subject.createdAt) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final timeParts = slot.time.split(':').map(int.parse).toList();
            if (timeParts.length >= 2) {
              final slotTime = DateTime(
                targetDate.year,
                targetDate.month,
                targetDate.day,
                timeParts[0],
                timeParts[1],
              );
              if (slotTime.isAfter(createdAt)) {
                // Just add as an unlogged class placeholder (no response)
                items.add({
                  'date': dateKey,
                  'slotId': slot.id,
                  'response': null,
                  'isMissed': false,
                  'slot': slot,
                  'subject': subject,
                  'isFuture':
                      targetDate.isAfter(now) ||
                      (targetDate.year == now.year &&
                          targetDate.month == now.month &&
                          targetDate.day == now.day &&
                          slotTime.isAfter(now)),
                });
              }
            }
          }
        }
      }
    }

    return items;
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final profile = ref.watch(profileProvider);
    final subjects = ref.watch(subjectProvider);
    final schedule = ref.watch(scheduleProvider);
    final responses = ref.watch(responseProvider);

    final historyItems = _processHistory(responses, schedule, subjects);

    // Group items by date for rendering
    final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    for (final item in historyItems) {
      final String date = item['date'] as String;
      if (!groupedByDate.containsKey(date)) groupedByDate[date] = [];
      groupedByDate[date]!.add(item);
    }

    // Stats for current month
    int daysActive = 0;
    int currentStreak = 0;
    int bestStreak = 0;
    int totalClasses = 0;
    int attendedClasses = 0;

    // Calculate streak (needs all historical data)
    final allDates = groupedByDate.keys.toList()..sort();
    int tempStreak = 0;
    for (final d in allDates) {
      final dItems = groupedByDate[d]!;
      bool attendedAny = dItems.any(
        (i) =>
            i['response'] != null &&
            i['isMissed'] == false &&
            (i['response'] as AttendanceResponse).attended,
      );
      bool missedAny = dItems.any(
        (i) =>
            i['isMissed'] == true ||
            (i['response'] != null &&
                !(i['response'] as AttendanceResponse).attended &&
                (i['response'] as AttendanceResponse).lectureHappened),
      );

      if (attendedAny && !missedAny) {
        tempStreak++;
        if (tempStreak > bestStreak) bestStreak = tempStreak;
      } else if (missedAny) {
        tempStreak = 0;
      }
    }

    // Calculate month stats
    final monthPrefix =
        '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';
    groupedByDate.forEach((date, items) {
      if (date.startsWith(monthPrefix)) {
        bool hasLogs = items.any((i) => i['response'] != null);
        if (hasLogs) daysActive++;

        for (var i in items) {
          if (i['response'] != null && i['isMissed'] == false) {
            final resp = i['response'] as AttendanceResponse;
            if (resp.lectureHappened) {
              totalClasses++;
              if (resp.attended) attendedClasses++;
            }
          } else if (i['isMissed'] == true) {
            totalClasses++;
          }
        }
      }
    });

    final double monthlyPercent = totalClasses > 0
        ? (attendedClasses / totalClasses) * 100
        : 0.0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 96.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Attendance Calendar',
                subtitle: 'Track attendance continuity and history',
                padding: const EdgeInsets.only(bottom: 16.0),
                trailing: HeaderIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh Calendar',
                  onTap: () async {
                    _toast('Refreshing history...', true);
                    try {
                      await SupabaseService.syncFromCloud(true);
                      ref.read(profileProvider.notifier).refresh();
                      ref.read(subjectProvider.notifier).refresh();
                      ref.read(scheduleProvider.notifier).refresh();
                      ref.read(responseProvider.notifier).refresh();
                    } catch (_) {}
                  },
                ),
              ),
              // Month Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  HeaderIconButton(
                    icon: Icons.chevron_left_rounded,
                    size: 38,
                    iconSize: 22,
                    tooltip: 'Previous Month',
                    onTap: () => _changeMonth(-1),
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_currentMonth),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  HeaderIconButton(
                    icon: Icons.chevron_right_rounded,
                    size: 38,
                    iconSize: 22,
                    tooltip: 'Next Month',
                    onTap: () => _changeMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Calendar Heatmap
              _buildCalendarGrid(groupedByDate, isDark),

              const SizedBox(height: 16),
              // Legend
              _buildLegend(isDark),

              const SizedBox(height: 32),

              // Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatBox(
                      'Days Active',
                      daysActive.toString(),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox(
                      'Best Streak',
                      '$bestStreak🔥',
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox(
                      'Monthly',
                      '${monthlyPercent.toStringAsFixed(1)}%',
                      isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(
    Map<String, List<Map<String, dynamic>>> groupedByDate,
    bool isDark,
  ) {
    // Generate days for the grid
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    );

    // offset for weekday (0 = Monday, 6 = Sunday)
    final startingOffset = firstDayOfMonth.weekday - 1;
    final totalDays = lastDayOfMonth.day;

    final int totalCells = startingOffset + totalDays;
    final int rows = (totalCells / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242729) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.outlineVariantLight.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (day) => SizedBox(
                    width: 32,
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.outlineLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: rows * 7,
            itemBuilder: (context, index) {
              if (index < startingOffset ||
                  index >= startingOffset + totalDays) {
                return const SizedBox(); // Empty cell
              }

              final dayNum = index - startingOffset + 1;
              final targetDate = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                dayNum,
              );
              final dateKey =
                  '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

              final items = groupedByDate[dateKey] ?? [];

              return _buildDayCell(targetDate, items, isDark, dateKey);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    List<Map<String, dynamic>> items,
    bool isDark,
    String dateKey,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isFuture = date.isAfter(today);

    Color cellColor = isDark
        ? const Color(0xFF2D3133)
        : const Color(0xFFF3F4F6); // Gray / No class
    Color textColor = isDark ? Colors.white60 : const Color(0xFF6B7280);
    BoxBorder? border;

    if (isToday) {
      border = Border.all(
        color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
        width: 2,
      );
      textColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    }

    if (isFuture && items.isNotEmpty) {
      // Future with classes scheduled
      cellColor = isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.6)
          : const Color(0xFFEEF2FF);
      textColor = isDark ? const Color(0xFF93C5FD) : AppColors.primaryLight;
      border = Border.all(
        color: isToday
            ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
            : (isDark
                ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                : const Color(0xFF818CF8).withValues(alpha: 0.5)),
        width: isToday ? 2 : 1,
      );
    } else if (items.isNotEmpty) {
      // Check status
      bool hasClass = false;
      int attended = 0;
      int missedOrBunked = 0;

      for (var item in items) {
        if (item['response'] != null && item['isMissed'] == false) {
          final resp = item['response'] as AttendanceResponse;
          if (resp.lectureHappened) {
            hasClass = true;
            if (resp.attended) {
              attended++;
            } else {
              missedOrBunked++;
            }
          }
        } else if (item['isMissed'] == true) {
          hasClass = true;
          missedOrBunked++;
        }
      }

      if (hasClass) {
        if (missedOrBunked == 0 && attended > 0) {
          cellColor = const Color(0xFF22C55E); // Bright Green
          textColor = Colors.white;
        } else if (attended == 0 && missedOrBunked > 0) {
          cellColor = const Color(0xFFEF4444); // Red
          textColor = Colors.white;
        } else {
          cellColor = const Color(0xFF86EFAC); // Light Green (Partial)
          textColor = const Color(0xFF14532D); // Dark Green for contrast
        }
      }
    }

    return GestureDetector(
      onTap: () {
        if (items.isNotEmpty) {
          _showDayDetailSheet(dateKey, items);
        } else {
          // No classes
          HapticFeedback.lightImpact();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Center(
          child: Text(
            date.day.toString(),
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: (isToday || items.isNotEmpty)
                  ? FontWeight.bold
                  : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(
          isDark ? const Color(0xFF2D3133) : const Color(0xFFF3F4F6),
          'No Class',
        ),
        const SizedBox(width: 12),
        _legendItem(const Color(0xFFEF4444), 'Bunked'),
        const SizedBox(width: 12),
        _legendItem(const Color(0xFF86EFAC), 'Partial'),
        const SizedBox(width: 12),
        _legendItem(const Color(0xFF22C55E), 'Attended'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.outlineLight,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(String title, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242729) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.outlineVariantLight.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.outlineLight,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ===== DAY DETAIL SHEET =====

  void _showDayDetailSheet(String date, List<Map<String, dynamic>> items) {
    String dateLabel = date;
    try {
      final parsed = DateTime.parse(date);
      dateLabel = DateFormat('EEEE, d MMMM yyyy').format(parsed);
    } catch (_) {}

    int attended = 0;
    int total = 0;
    for (var i in items) {
      if (i['isFuture'] != true && i['response'] != null) {
        if (i['isMissed'] == true) {
          total++;
        } else {
          final resp = i['response'] as AttendanceResponse;
          if (resp.lectureHappened) {
            total++;
            if (resp.attended) attended++;
          }
        }
      }
    }

    String summaryText = total > 0
        ? '$attended/$total attended (${((attended / total) * 100).toStringAsFixed(1)}%)'
        : 'No attendance logged';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 24.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D2022) : const Color(0xFFFFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                summaryText,
                style: const TextStyle(
                  color: AppColors.outlineLight,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _buildHistoryCard(items[index], date);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item, String date) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Subject subject = item['subject'] as Subject;
    final ScheduleSlot slot = item['slot'] as ScheduleSlot;
    final AttendanceResponse? response =
        item['response'] as AttendanceResponse?;
    final bool isMissed = item['isMissed'] == true;
    final bool isFuture = item['isFuture'] == true;

    String statusLabel = 'No Class';
    Color statusColor = AppColors.outlineLight;
    IconData icon = Icons.event_busy;
    Color bg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : AppColors.bgSurfaceLowLight;

    if (isFuture) {
      statusLabel = 'Upcoming';
      statusColor = AppColors.outlineLight;
      icon = Icons.schedule;
      bg = Colors.grey.withValues(alpha: 0.1);
    } else if (response == null) {
      statusLabel = 'Unlogged';
      statusColor = AppColors.outlineLight;
      icon = Icons.help_outline;
      bg = Colors.grey.withValues(alpha: 0.1);
    } else if (isMissed) {
      statusLabel = 'Missed';
      statusColor = AppColors.outlineLight;
      icon = Icons.pending_actions;
      bg = Colors.grey.withValues(alpha: 0.1);
    } else if (response.lectureHappened) {
      if (response.attended) {
        statusLabel = 'Attended';
        statusColor = const Color(0xFF16A34A); // Green
        icon = Icons.check_circle;
        bg = const Color(0xFF22C55E).withValues(alpha: 0.1);
      } else {
        statusLabel = 'Bunked';
        statusColor = AppColors.redBg; // Red
        icon = Icons.cancel;
        bg = AppColors.redBg.withValues(alpha: 0.1);
      }
    }

    return GestureDetector(
      onTap: () {
        if (!isFuture) {
          Navigator.pop(context); // Close day detail
          _showEditHistorySheet(item, date);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242729) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.outlineVariantLight.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 10,
                        color: AppColors.outlineLight,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${TimeFormatter.formatTime(slot.time)} · ${slot.slotType == 'practical' ? 'Practical' : 'Theory'}',
                        style: const TextStyle(
                          color: AppColors.outlineLight,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: statusColor, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 8.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== RETROACTIVE SHEET EDIT LOG =====

  void _showEditHistorySheet(Map<String, dynamic> item, String date) {
    final Subject subject = item['subject'] as Subject;
    final ScheduleSlot slot = item['slot'] as ScheduleSlot;
    final AttendanceResponse? response =
        item['response'] as AttendanceResponse?;
    final bool isMissed = item['isMissed'] == true;

    String readableDate = date;
    try {
      final parsed = DateTime.parse(date);
      readableDate = DateFormat('d MMMM yyyy').format(parsed);
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        String currentStatus = 'unlogged';
        if (response != null) {
          currentStatus = isMissed
              ? 'missed'
              : (response.attended
                    ? 'attended'
                    : (response.lectureHappened ? 'bunked' : 'no_class'));
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 24.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D2022) : const Color(0xFFFFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                subject.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$readableDate • ${TimeFormatter.formatTime(slot.time)}',
                style: const TextStyle(
                  color: AppColors.outlineLight,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Option cards list
              Column(
                children: [
                  _buildOptionCard(
                    'I Attended',
                    Icons.check_circle,
                    const Color(0xFF16A34A),
                    const Color(0xFF22C55E).withValues(alpha: 0.08),
                    currentStatus == 'attended',
                    () => _submitRetroactiveCorrection(
                      date,
                      slot.id,
                      response,
                      isMissed,
                      'attended',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildOptionCard(
                    'I Bunked',
                    Icons.cancel,
                    AppColors.redBg,
                    AppColors.redBg.withValues(alpha: 0.08),
                    currentStatus == 'bunked',
                    () => _submitRetroactiveCorrection(
                      date,
                      slot.id,
                      response,
                      isMissed,
                      'bunked',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildOptionCard(
                    'No Class Held',
                    Icons.event_busy,
                    AppColors.outlineLight,
                    AppColors.outlineLight.withValues(alpha: 0.08),
                    currentStatus == 'no_class',
                    () => _submitRetroactiveCorrection(
                      date,
                      slot.id,
                      response,
                      isMissed,
                      'no_class',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionCard(
    String label,
    IconData icon,
    Color activeColor,
    Color activeBg,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? activeBg
              : (isDark
                    ? const Color(0xFF242729)
                    : AppColors.bgSurfaceLowLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppColors.outlineVariantLight.withValues(alpha: 0.3)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : AppColors.outlineLight,
              size: 20,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? activeColor
                    : (isDark
                          ? AppColors.textMainDark
                          : AppColors.textMainLight),
                fontSize: 14.5,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check, color: activeColor, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRetroactiveCorrection(
    String date,
    String slotId,
    AttendanceResponse? oldResponse,
    bool isMissed,
    String selectedStatus,
  ) async {
    Navigator.pop(context); // Close sheet
    _toast('Updating attendance...', true);

    final newResponse = AttendanceResponse(
      id: oldResponse?.id ?? '',
      userId: oldResponse?.userId ?? '',
      slotId: slotId,
      date: date,
      lectureHappened: selectedStatus != 'no_class',
      attended: selectedStatus == 'attended',
      createdAt: oldResponse?.createdAt ?? '',
    );

    await ref
        .read(responseProvider.notifier)
        .update(
          date: date,
          slotId: slotId,
          oldResponse: isMissed ? null : oldResponse,
          newResponse: newResponse,
        );

    _toast('Updated successfully!', true);
  }
}
