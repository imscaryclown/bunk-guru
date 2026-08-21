import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../services/providers.dart';
import '../../../services/supabase_service.dart';
import '../../../models/subject.dart';
import '../../../models/schedule_slot.dart';
import '../../../models/attendance_response.dart';
import '../../../widgets/header_icon_button.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  // Set to track expanded date groups
  final Set<String> _expandedDates = {};

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
            items.push({
              'date': dateKey,
              'slotId': slotId,
              'response': response,
              'slot': slot,
              'subject': subject,
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
          // Has the class time passed today/on that day?
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
              // Only backfill if subject was created before that class slot
              final DateTime createdAt =
                  DateTime.tryParse(subject.createdAt) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              if (slotTime.isAfter(createdAt)) {
                items.push({
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

    // Sort: Newest date first, then newest time first
    items.sort((a, b) {
      final int dateCompare = (b['date'] as String).compareTo(
        a['date'] as String,
      );
      if (dateCompare != 0) return dateCompare;

      final String timeA = (a['slot'] as ScheduleSlot).time;
      final String timeB = (b['slot'] as ScheduleSlot).time;
      return timeB.compareTo(timeA);
    });

    return items;
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
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in historyItems) {
      final String date = item['date'] as String;
      if (!grouped.containsKey(date)) grouped[date] = [];
      grouped[date]!.add(item);
    }

    final List<String> sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final String initial = profile?.displayName.isNotEmpty == true
        ? profile!.displayName[0]
        : 'S';
    final Widget avatar = profile?.avatarUrl.isNotEmpty == true
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
                fontWeight: FontWeight.bold,
              ),
            ),
          );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        leadingWidth: 48,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: avatar,
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFFB4136D)],
          ).createShader(bounds),
          child: const Text(
            'Check-in History',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 24,
              fontFamily: 'Inter',
            ),
          ),
        ),
        actions: [
          HeaderIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            size: 38,
            iconSize: 20,
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
      body: SafeArea(
        child: historyItems.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 96.0),
                itemCount: sortedDates.length,
                itemBuilder: (context, index) {
                  final String date = sortedDates[index];
                  final List<Map<String, dynamic>> dateItems = grouped[date]!;
                  return _buildDateAccordion(date, dateItems);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.outlineLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.history,
              color: AppColors.outlineLight,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No History Yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Once you start checking in, your logs show up here.',
            style: TextStyle(color: AppColors.outlineLight, fontSize: 12),
          ),
        ],
      ).animate().fade(duration: 400.ms),
    );
  }

  // Accordion collapsible Date groups
  Widget _buildDateAccordion(String date, List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterdayStr = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().subtract(const Duration(days: 1)));

    String dateLabel = date;
    try {
      final parsed = DateTime.parse(date);
      dateLabel = DateFormat('d MMM yyyy').format(parsed);
    } catch (_) {}

    if (date == todayStr) dateLabel = 'Today';
    if (date == yesterdayStr) dateLabel = 'Yesterday';

    final bool isExpanded = _expandedDates.contains(date);

    // Summary calculations (e.g. 2 attended, 1 bunked)
    final int attended = items
        .where(
          (i) =>
              i['isMissed'] != true &&
              (i['response'] as AttendanceResponse).attended,
        )
        .length;
    final int bunked = items
        .where(
          (i) =>
              i['isMissed'] != true &&
              !(i['response'] as AttendanceResponse).attended &&
              (i['response'] as AttendanceResponse).lectureHappened,
        )
        .length;
    final int missed = items.where((i) => i['isMissed'] == true).length;

    final List<String> summaries = [];
    if (attended > 0) summaries.add('$attended attended');
    if (bunked > 0) summaries.add('$bunked bunked');
    if (missed > 0) summaries.add('$missed missed');
    final String summaryText = summaries.isNotEmpty
        ? summaries.join(', ')
        : 'No entries';

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242729) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.outlineVariantLight.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isExpanded) {
                  _expandedDates.remove(date);
                } else {
                  _expandedDates.add(date);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabel.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summaryText,
                          style: const TextStyle(
                            color: AppColors.outlineLight,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: isDark
                          ? AppColors.outlineDark
                          : AppColors.outlineLight,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Accordion Body (timeline listing)
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: isDark
                  ? Colors.black.withValues(alpha: 0.1)
                  : AppColors.bgSurfaceLowLight.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Stack(
                  children: [
                    // Vertical Timeline Line
                    Positioned(
                      left: -2,
                      top: 4,
                      bottom: 4,
                      child: Container(
                        width: 1.5,
                        color: isDark
                            ? Colors.white10
                            : Colors.indigo.withValues(alpha: 0.08),
                      ),
                    ),
                    Column(
                      children: items
                          .map((i) => _buildHistoryCard(i, date))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item, String date) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Subject subject = item['subject'] as Subject;
    final ScheduleSlot slot = item['slot'] as ScheduleSlot;
    final AttendanceResponse response = item['response'] as AttendanceResponse;
    final bool isMissed = item['isMissed'] == true;

    // Determine colors and badge labels based on active check-in status
    String statusLabel = 'No Class';
    Color statusColor = AppColors.outlineLight;
    IconData icon = Icons.event_busy;
    Color bg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : AppColors.bgSurfaceLowLight;
    Color dotColor = AppColors.outlineLight;

    if (isMissed) {
      statusLabel = 'Missed';
      statusColor = AppColors.outlineLight;
      icon = Icons.pending_actions;
      bg = Colors.grey.withValues(alpha: 0.1);
      dotColor = AppColors.outlineLight.withValues(alpha: 0.5);
    } else if (response.lectureHappened) {
      if (response.attended) {
        statusLabel = 'Attended';
        statusColor = const Color(0xFF16A34A); // Green
        icon = Icons.check_circle;
        bg = const Color(0xFF22C55E).withValues(alpha: 0.1);
        dotColor = const Color(0xFF22C55E);
      } else {
        statusLabel = 'Bunked';
        statusColor = AppColors.redBg; // Red
        icon = Icons.cancel;
        bg = AppColors.redBg.withValues(alpha: 0.1);
        dotColor = AppColors.redBg;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Timeline Node Dot
          Positioned(
            left: -22.5,
            top: 15,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF1D2022) : Colors.white,
                  width: 1.5,
                ),
              ),
            ),
          ),

          // Log card details
          GestureDetector(
            onTap: () => _showEditHistorySheet(item),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1D2022)
                    : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
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

                  // Pill Badge status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
          ),
        ],
      ),
    );
  }

  // ===== RETROACTIVE SHEET EDIT LOG =====

  void _showEditHistorySheet(Map<String, dynamic> item) {
    final Subject subject = item['subject'] as Subject;
    final ScheduleSlot slot = item['slot'] as ScheduleSlot;
    final String date = item['date'] as String;
    final AttendanceResponse response = item['response'] as AttendanceResponse;
    final bool isMissed = item['isMissed'] == true;

    // Helper to calculate readable date string
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

        final String currentStatus = isMissed
            ? 'missed'
            : (response.attended
                  ? 'attended'
                  : (response.lectureHappened ? 'bunked' : 'no_class'));

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
    AttendanceResponse oldResponse,
    bool isMissed,
    String selectedStatus,
  ) async {
    Navigator.pop(context); // Close sheet
    _toast('Updating attendance...', true);

    final newResponse = AttendanceResponse(
      id: oldResponse.id,
      userId: oldResponse.userId,
      slotId: slotId,
      date: date,
      lectureHappened: selectedStatus != 'no_class',
      attended: selectedStatus == 'attended',
      createdAt: oldResponse.createdAt,
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
}

extension ListPush<T> on List<T> {
  void push(T val) => add(val);
}
