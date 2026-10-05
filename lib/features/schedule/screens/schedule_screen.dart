import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../services/providers.dart';
import '../../../services/supabase_service.dart';
import '../../../models/subject.dart';
import '../../../models/schedule_slot.dart';

import '../../../widgets/page_header.dart';
import '../../../widgets/header_icon_button.dart';
import '../../../widgets/batch_import_success_dialog.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  int _selectedDay = (DateTime.now().weekday - 1); // 0=Mon..6=Sun
  final List<String> _dayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  final List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<Color> _slotColors = [
    AppColors.primaryLight,
    AppColors.secondaryLight,
    const Color(0xFF006A7C),
  ];
  final List<IconData> _slotIcons = [
    Icons.calculate,
    Icons.science,
    Icons.computer,
    Icons.account_tree,
    Icons.code,
  ];

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

  // Generate date and index models for the current week
  List<Map<String, dynamic>> _getWeekDates() {
    final today = DateTime.now();
    final int weekday = today.weekday;
    final monday = today.subtract(Duration(days: weekday - 1));

    final List<Map<String, dynamic>> days = [];
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      days.add({'date': date.day, 'dayIndex': i, 'label': _dayLabels[i]});
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final subjects = ref.watch(subjectProvider);
    final schedule = ref.watch(scheduleProvider);

    // Filter and sort schedule slots for the active selected day index
    final List<ScheduleSlot> daySlots =
        schedule.where((s) => s.dayOfWeek == _selectedDay).toList()
          ..sort((a, b) => a.time.compareTo(b.time));

    final weekDates = _getWeekDates();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ===== 1. Day Selector Strip =====
            PageHeader(
              title: 'This Week',
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HeaderIconButton(
                    icon: Icons.file_download_outlined,
                    tooltip: 'Import Timetable',
                    onTap: () => context.push('/import-timetable'),
                  ),
                  const SizedBox(width: 8),
                  HeaderIconButton(
                    icon: Icons.people_outline_rounded,
                    tooltip: 'Share Timetable',
                    onTap: () => _showShareSheet(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 72,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: weekDates.length,
                      itemBuilder: (context, index) {
                        final d = weekDates[index];
                        final bool isActive = index == _selectedDay;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedDay = d['dayIndex'] as int;
                            });
                          },
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 54),
                            margin: const EdgeInsets.only(right: 10.0),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primaryLight
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : AppColors.bgSurfaceLowLight),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primaryLight
                                            .withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  d['label'] as String,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? AppColors.primaryFixed
                                        : AppColors.outlineLight,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${d['date']}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? Colors.white
                                        : (isDark
                                              ? AppColors.textMainDark
                                              : AppColors.textMainLight),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ===== 2. Schedule Slot List =====
            Expanded(
              child: daySlots.isEmpty
                  ? _buildEmptySchedule()
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: 20.0,
                        right: 20.0,
                        top: 16.0,
                        bottom: 120.0 + MediaQuery.of(context).padding.bottom,
                      ),
                      itemCount: daySlots.length,
                      itemBuilder: (context, index) {
                        final slot = daySlots[index];
                        final sub = subjects.firstWhere(
                          (s) => s.id == slot.subjectId,
                          orElse: () => Subject(
                            id: '',
                            userId: '',
                            name: 'Unknown',
                            createdAt: '',
                          ),
                        );

                        final color = _slotColors[index % _slotColors.length];
                        final icon = _getIconData(sub.icon);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left time labels
                              Container(
                                width: 75,
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      TimeFormatter.formatTime(slot.time),
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(fontSize: 11),
                                    ),
                                    if (slot.endTime.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'to ${TimeFormatter.formatTime(slot.endTime)}',
                                        style: TextStyle(
                                          color: isDark
                                              ? AppColors.outlineDark
                                              : AppColors.outlineLight,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Right Card details
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showEditSlotSheet(slot),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF242729)
                                          : const Color(0xFFFFFFFF),
                                      borderRadius: BorderRadius.circular(16.0),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.05,
                                              )
                                            : AppColors.outlineVariantLight
                                                  .withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      children: [
                                        // Left accent bar
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 3,
                                            color: color,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 10.0,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                  color: color.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  icon,
                                                  color: color,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      sub.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.location_on,
                                                          size: 12,
                                                          color: AppColors
                                                              .outlineLight,
                                                        ),
                                                        const SizedBox(
                                                          width: 2,
                                                        ),
                                                        Text(
                                                          slot.room.isNotEmpty
                                                              ? slot.room
                                                              : 'TBD',
                                                          style: const TextStyle(
                                                            color: AppColors
                                                                .outlineLight,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        const Text(
                                                          '•',
                                                          style: TextStyle(
                                                            color: AppColors
                                                                .outlineLight,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Text(
                                                          slot.slotType ==
                                                                  'practical'
                                                              ? 'Practical'
                                                              : 'Theory',
                                                          style: const TextStyle(
                                                            color: AppColors
                                                                .primaryLight,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
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
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 93.0, right: 3.0),
        child: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          elevation: 4,
          onPressed: () => _showAddSlotSheet(),
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  Widget _buildEmptySchedule() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF006A7C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.calendar_month,
              color: Color(0xFF00505F),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Classes Today',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add time slots to build your weekly schedule.',
            style: TextStyle(color: AppColors.outlineLight, fontSize: 12),
          ),
        ],
      ).animate().fade(duration: 400.ms),
    );
  }

  // ===== BOTTOM SHEETS FOR TIMETABLE ACTIONS =====

  void _showAddSlotSheet() {
    final subjects = ref.read(subjectProvider);
    if (subjects.isEmpty) {
      _toast('Add subjects first under the SUBJECTS tab!', false);
      return;
    }

    String selectedSubjectId = subjects.first.id;
    int selectedDay = _selectedDay;
    String selectedType = 'theory';
    final startTimeController = TextEditingController(text: '09:00');
    final endTimeController = TextEditingController(text: '10:00');
    final roomController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1D2022)
                      : const Color(0xFFFFFFFF),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
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
                  const Text(
                    'Add Time Slot',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  // Subject dropdown
                  const Text(
                    'SUBJECT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.outlineLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.bgSurfaceContainerDark
                          : AppColors.bgSurfaceContainerLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSubjectId,
                        isExpanded: true,
                        dropdownColor: isDark
                            ? const Color(0xFF1D2022)
                            : Colors.white,
                        items: subjects.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedSubjectId = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Day dropdown
                  const Text(
                    'DAY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.outlineLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.bgSurfaceContainerDark
                          : AppColors.bgSurfaceContainerLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedDay,
                        isExpanded: true,
                        dropdownColor: isDark
                            ? const Color(0xFF1D2022)
                            : Colors.white,
                        items: List.generate(7, (i) {
                          return DropdownMenuItem(
                            value: i,
                            child: Text(_dayNames[i]),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedDay = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Class Type Toggle Chips
                  const Text(
                    'CLASS TYPE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.outlineLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          color: selectedType == 'theory'
                              ? AppColors.primaryLight.withValues(alpha: 0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: selectedType == 'theory'
                                ? AppColors.primaryLight
                                : AppColors.outlineVariantLight,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          onTap: () =>
                              setModalState(() => selectedType = 'theory'),
                          child: Text(
                            'THEORY',
                            style: TextStyle(
                              color: selectedType == 'theory'
                                  ? AppColors.primaryLight
                                  : AppColors.outlineLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          color: selectedType == 'practical'
                              ? AppColors.primaryLight.withValues(alpha: 0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: selectedType == 'practical'
                                ? AppColors.primaryLight
                                : AppColors.outlineVariantLight,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          onTap: () =>
                              setModalState(() => selectedType = 'practical'),
                          child: Text(
                            'PRACTICAL',
                            style: TextStyle(
                              color: selectedType == 'practical'
                                  ? AppColors.primaryLight
                                  : AppColors.outlineLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Start and End Times
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: startTimeController,
                          hintText: 'e.g. 09:00',
                          labelText: 'START TIME (HH:MM)',
                          keyboardType: TextInputType.datetime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextField(
                          controller: endTimeController,
                          hintText: 'e.g. 10:00',
                          labelText: 'END TIME (HH:MM)',
                          keyboardType: TextInputType.datetime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Room Input
                  CustomTextField(
                    controller: roomController,
                    hintText: 'e.g. Room 302',
                    labelText: 'ROOM / LOCATION',
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  CustomButton(
                    color: const Color(0xFF4F46E5),
                    onTap: () async {
                      if (selectedSubjectId.isEmpty) return;
                      await ref
                          .read(scheduleProvider.notifier)
                          .add(
                            subjectId: selectedSubjectId,
                            dayOfWeek: selectedDay,
                            time: startTimeController.text.trim(),
                            endTime: endTimeController.text.trim(),
                            slotType: selectedType,
                            room: roomController.text.trim(),
                          );
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      'ADD SLOT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
        );
      },
    );
  }

  void _showEditSlotSheet(ScheduleSlot slot) {
    final subjects = ref.read(subjectProvider);
    String selectedSubjectId = slot.subjectId;
    int selectedDay = slot.dayOfWeek;
    String selectedType = slot.slotType;
    final startTimeController = TextEditingController(text: slot.time);
    final endTimeController = TextEditingController(text: slot.endTime);
    final roomController = TextEditingController(text: slot.room);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1D2022)
                      : const Color(0xFFFFFFFF),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
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
                  const Text(
                    'Edit Time Slot',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  // Subject dropdown
                  const Text(
                    'SUBJECT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.outlineLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.bgSurfaceContainerDark
                          : AppColors.bgSurfaceContainerLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSubjectId,
                        isExpanded: true,
                        dropdownColor: isDark
                            ? const Color(0xFF1D2022)
                            : Colors.white,
                        items: subjects.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedSubjectId = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Day dropdown
                  const Text(
                    'DAY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.outlineLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.bgSurfaceContainerDark
                          : AppColors.bgSurfaceContainerLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedDay,
                        isExpanded: true,
                        dropdownColor: isDark
                            ? const Color(0xFF1D2022)
                            : Colors.white,
                        items: List.generate(7, (i) {
                          return DropdownMenuItem(
                            value: i,
                            child: Text(_dayNames[i]),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedDay = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Class Type Toggle Chips
                  const Text(
                    'CLASS TYPE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.outlineLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          color: selectedType == 'theory'
                              ? AppColors.primaryLight.withValues(alpha: 0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: selectedType == 'theory'
                                ? AppColors.primaryLight
                                : AppColors.outlineVariantLight,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          onTap: () =>
                              setModalState(() => selectedType = 'theory'),
                          child: Text(
                            'THEORY',
                            style: TextStyle(
                              color: selectedType == 'theory'
                                  ? AppColors.primaryLight
                                  : AppColors.outlineLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          color: selectedType == 'practical'
                              ? AppColors.primaryLight.withValues(alpha: 0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: selectedType == 'practical'
                                ? AppColors.primaryLight
                                : AppColors.outlineVariantLight,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          onTap: () =>
                              setModalState(() => selectedType = 'practical'),
                          child: Text(
                            'PRACTICAL',
                            style: TextStyle(
                              color: selectedType == 'practical'
                                  ? AppColors.primaryLight
                                  : AppColors.outlineLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Times
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: startTimeController,
                          hintText: 'e.g. 09:00',
                          labelText: 'START TIME (HH:MM)',
                          keyboardType: TextInputType.datetime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextField(
                          controller: endTimeController,
                          hintText: 'e.g. 10:00',
                          labelText: 'END TIME (HH:MM)',
                          keyboardType: TextInputType.datetime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Room Input
                  CustomTextField(
                    controller: roomController,
                    hintText: 'e.g. Room 302',
                    labelText: 'ROOM / LOCATION',
                  ),
                  const SizedBox(height: 20),

                  // Submit & Delete Row
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          color: isDark
                              ? const Color(0xFF282C2F)
                              : Colors.red.withValues(alpha: 0.06),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.2),
                          ),
                          onTap: () async {
                            final confirmDel = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Slot?'),
                                content: const Text(
                                  'Are you sure you want to remove this time slot from your schedule?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('CANCEL'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text(
                                      'DELETE',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirmDel == true) {
                              await ref
                                  .read(scheduleProvider.notifier)
                                  .delete(slot.id);
                              if (mounted) {
                                Navigator.pop(context);
                              }
                            }
                          },
                          child: const Text(
                            'DELETE',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: CustomButton(
                          color: const Color(0xFF4F46E5),
                          onTap: () async {
                            await ref
                                .read(scheduleProvider.notifier)
                                .update(slot.id, {
                                  'subject_id': selectedSubjectId,
                                  'day_of_week': selectedDay,
                                  'time': startTimeController.text.trim(),
                                  'end_time': endTimeController.text.trim(),
                                  'slot_type': selectedType,
                                  'room': roomController.text.trim(),
                                });
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          },
                          child: const Text(
                            'SAVE CHANGES',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
        );
      },
    );
  }

  void _showShareSheet() {
    final shareCodeController = TextEditingController();
    bool isGenerating = false;
    String generatedCode = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1D2022)
                      : const Color(0xFFFFFFFF),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
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
                  const Text(
                    'Batch Schedule',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Share your schedule with classmates or load one.',
                    style: TextStyle(
                      color: AppColors.outlineLight,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Load Schedule Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF242729)
                          : AppColors.bgSurfaceContainerLight.withValues(
                              alpha: 0.5,
                            ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Load Class Schedule',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: shareCodeController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                maxLength: 6,
                                decoration: InputDecoration(
                                  hintText: 'Enter 6-digit code',
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  fillColor: isDark
                                      ? const Color(0xFF1D2022)
                                      : Colors.white,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 80,
                              height: 42,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () async {
                                  final code = shareCodeController.text.trim();
                                  if (code.length < 5) {
                                    _toast('Please enter a valid code', false);
                                    return;
                                  }

                                  try {
                                    final res =
                                        await SupabaseService.fetchShareData(
                                          code,
                                        );
                                    final subjectsJson =
                                        res['subjects'] as List<dynamic>;
                                    final scheduleJson =
                                        res['schedule'] as List<dynamic>;

                                    await SupabaseService.commitScheduleOnly(
                                      subjectsJson,
                                      scheduleJson,
                                    );
                                    ref
                                        .read(subjectProvider.notifier)
                                        .refresh();
                                    ref
                                        .read(scheduleProvider.notifier)
                                        .refresh();

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      BatchImportSuccessDialog.show(
                                        context: context,
                                        title: 'Batch Joined Successfully!',
                                        subtitle:
                                            'Your course tracker and timetable are now synced with this batch.',
                                        subjectCount: subjectsJson.length,
                                        slotCount: scheduleJson.length,
                                      );
                                    }
                                  } catch (e) {
                                    _toast('Failed to load code: $e', false);
                                  }
                                },
                                child: const Text(
                                  'LOAD',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Generate Share Code Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF242729)
                          : AppColors.bgSurfaceLowLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.outlineVariantLight.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Share My Schedule',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Generate a code to share your current subjects & schedule with others.',
                          style: TextStyle(
                            color: AppColors.outlineLight,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (generatedCode.isEmpty)
                          CustomButton(
                            color: Colors.transparent,
                            border: Border.all(
                              color: AppColors.primaryLight,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            onTap: isGenerating
                                ? null
                                : () async {
                                    setModalState(() => isGenerating = true);
                                    try {
                                      final code =
                                          await SupabaseService.generateShareCode();
                                      setModalState(() {
                                        generatedCode = code;
                                        isGenerating = false;
                                      });
                                    } catch (e) {
                                      setModalState(() => isGenerating = false);
                                      _toast(
                                        e
                                            .toString()
                                            .replaceAll('Exception:', '')
                                            .trim(),
                                        false,
                                      );
                                    }
                                  },
                            child: isGenerating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'GENERATE SHARE CODE',
                                    style: TextStyle(
                                      color: AppColors.primaryLight,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1D2022)
                                  : AppColors.bgSurfaceContainerLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'YOUR CODE',
                                  style: TextStyle(
                                    color: AppColors.outlineLight,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  generatedCode,
                                  style: const TextStyle(
                                    color: AppColors.primaryLight,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
        );
      },
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
}
