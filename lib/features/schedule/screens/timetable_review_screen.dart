import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../services/providers.dart';
import '../../../services/supabase_service.dart';
import '../services/timetable_parser.dart';

class TimetableReviewScreen extends ConsumerStatefulWidget {
  final List<dynamic> slots;

  const TimetableReviewScreen({super.key, required this.slots});

  @override
  ConsumerState<TimetableReviewScreen> createState() =>
      _TimetableReviewScreenState();
}

class _TimetableReviewScreenState extends ConsumerState<TimetableReviewScreen> {
  late List<ParsedSlot> _slots;
  String _conflictMode = 'merge'; // 'merge' or 'replace'
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _slots = widget.slots.cast<ParsedSlot>();
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.redBg : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _importData() async {
    setState(() {
      _isSaving = true;
    });

    final currentSubjects = ref.read(subjectProvider);
    final currentSlots = ref.read(scheduleProvider);
    final profile = ref.read(profileProvider);
    final userId = profile?.id ?? 'unknown_user';

    try {
      // 1. Handle "Replace" mode by clearing existing schedule
      if (_conflictMode == 'replace' && currentSlots.isNotEmpty) {
        for (final slot in currentSlots) {
          await ref.read(scheduleProvider.notifier).delete(slot.id);
        }
      }

      // 2. Process subjects and create missing ones
      final Map<String, String> subjectNameToId = {
        for (var sub in currentSubjects) sub.name.toLowerCase().trim(): sub.id,
      };

      for (var slot in _slots) {
        final subName = slot.subjectName.toLowerCase().trim();
        if (!subjectNameToId.containsKey(subName)) {
          // Create new subject
          final newSubject = await SupabaseService.addSubject(
            name: slot.subjectName,
            professor: slot.professor,
            hasPractical: slot.slotType == 'practical',
          );
          subjectNameToId[subName] = newSubject.id;
        }
      }

      // 3. Create schedule slots
      for (var parsed in _slots) {
        final subName = parsed.subjectName.toLowerCase().trim();
        final subjectId = subjectNameToId[subName]!;

        await SupabaseService.addScheduleSlot(
          subjectId: subjectId,
          dayOfWeek: parsed.dayOfWeek,
          time: parsed.startTime,
          endTime: parsed.endTime,
          slotType: parsed.slotType,
          room: parsed.room,
        );
      }

      ref.read(subjectProvider.notifier).refresh();
      ref.read(scheduleProvider.notifier).refresh();

      _toast('Timetable imported successfully!');

      // Navigate back to schedule screen
      if (context.mounted) {
        context.go('/home'); // Send to home which has Schedule tab
      }
    } catch (e) {
      _toast('Error importing: $e', isError: true);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentSlots = ref.watch(scheduleProvider);

    // Group parsed slots by day
    final Map<int, List<ParsedSlot>> grouped = {};
    for (var slot in _slots) {
      if (!grouped.containsKey(slot.dayOfWeek)) grouped[slot.dayOfWeek] = [];
      grouped[slot.dayOfWeek]!.add(slot);
    }

    // Sort days and slots
    final sortedDays = grouped.keys.toList()..sort();
    for (var key in sortedDays) {
      grouped[key]!.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    final double avgConfidence = _slots.isEmpty
        ? 0
        : _slots.map((s) => s.confidence).reduce((a, b) => a + b) /
              _slots.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Review Imported Schedule',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Confidence Badge
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: avgConfidence > 0.8
                                    ? const Color(
                                        0xFF22C55E,
                                      ).withValues(alpha: 0.1)
                                    : AppColors.redBg.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    avgConfidence > 0.8
                                        ? Icons.check_circle
                                        : Icons.warning,
                                    color: avgConfidence > 0.8
                                        ? const Color(0xFF16A34A)
                                        : AppColors.redBg,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'AI Confidence: ${(avgConfidence * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color: avgConfidence > 0.8
                                          ? const Color(0xFF16A34A)
                                          : AppColors.redBg,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (currentSlots.isNotEmpty) ...[
                            _buildConflictCard(isDark),
                            const SizedBox(height: 24),
                          ],

                          if (_slots.isEmpty)
                            const Center(
                              child: Text('No classes found in input'),
                            )
                          else
                            ...sortedDays.map(
                              (day) =>
                                  _buildDaySection(day, grouped[day]!, isDark),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1D2022) : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _slots.isEmpty ? null : _importData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Import All ✓',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

  Widget _buildConflictCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryFixed.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primaryFixed),
              SizedBox(width: 8),
              Text(
                'Existing Schedule Detected',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryFixed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RadioListTile<String>(
            title: const Text(
              'Merge',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text(
              'Add new classes, keep existing ones',
              style: TextStyle(fontSize: 12),
            ),
            value: 'merge',
            groupValue: _conflictMode,
            onChanged: (v) => setState(() => _conflictMode = v!),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            title: const Text(
              'Start Fresh',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text(
              'Delete old schedule, keep attendance history',
              style: TextStyle(fontSize: 12),
            ),
            value: 'replace',
            groupValue: _conflictMode,
            onChanged: (v) => setState(() => _conflictMode = v!),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(int dayOfWeek, List<ParsedSlot> slots, bool isDark) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            days[dayOfWeek],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...slots.map((s) => _buildSlotCard(s, isDark)),
        ],
      ),
    );
  }

  Widget _buildSlotCard(ParsedSlot slot, bool isDark) {
    bool hasWarning =
        slot.confidence < 0.7 ||
        slot.room.toLowerCase() == 'unknown' ||
        slot.room.isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242729) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasWarning
              ? AppColors.outlineVariantLight
              : const Color(0xFF4F46E5),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${TimeFormatter.formatTime(slot.startTime)} - ${slot.subjectName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Room: ${slot.room} • ${slot.slotType}',
                  style: TextStyle(
                    color: hasWarning
                        ? AppColors.redBg
                        : AppColors.outlineLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            hasWarning ? Icons.warning_amber : Icons.check_circle,
            color: hasWarning ? AppColors.redBg : const Color(0xFF16A34A),
          ),
        ],
      ),
    );
  }
}
