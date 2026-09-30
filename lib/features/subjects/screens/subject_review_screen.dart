import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../services/providers.dart';
import '../../../services/supabase_service.dart';
import '../services/subject_parser.dart';

class SubjectReviewScreen extends ConsumerStatefulWidget {
  final List<dynamic> subjects;

  const SubjectReviewScreen({super.key, required this.subjects});

  @override
  ConsumerState<SubjectReviewScreen> createState() =>
      _SubjectReviewScreenState();
}

class _SubjectReviewScreenState extends ConsumerState<SubjectReviewScreen> {
  late List<ParsedSubject> _subjects;
  String _conflictMode = 'merge'; // 'merge' or 'replace'
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _subjects = widget.subjects.cast<ParsedSubject>();
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

    try {
      // 1. Handle "Replace" mode by clearing existing subjects
      if (_conflictMode == 'replace' && currentSubjects.isNotEmpty) {
        for (final sub in currentSubjects) {
          await ref.read(subjectProvider.notifier).delete(sub.id);
        }
      }

      // Refresh after potential deletions
      final updatedCurrentSubjects = ref.read(subjectProvider);
      final Map<String, String> existingSubjectNames = {
        for (var sub in updatedCurrentSubjects)
          sub.name.toLowerCase().trim(): sub.id,
      };

      // 2. Process and create subjects
      for (var parsed in _subjects) {
        final subName = parsed.subjectName.toLowerCase().trim();

        // If merge mode and it exists, we skip it (or could update it, but skip is safer to avoid overwriting good data)
        if (existingSubjectNames.containsKey(subName)) {
          continue;
        }

        await SupabaseService.addSubject(
          name: parsed.subjectName,
          professor: parsed.professor,
          totalClasses: parsed.totalClasses,
          attendedClasses: parsed.attendedClasses,
          hasPractical: parsed.hasPractical,
          practicalTotal: parsed.practicalTotal,
          practicalAttended: parsed.practicalAttended,
        );
      }

      ref.read(subjectProvider.notifier).refresh();

      _toast('Subjects imported successfully!');

      if (context.mounted) {
        context.go('/home'); // Go back to subjects tab
      }
    } catch (e) {
      _toast('Error importing: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentSubjects = ref.watch(subjectProvider);

    final double avgConfidence = _subjects.isEmpty
        ? 0
        : _subjects.map((s) => s.confidence).reduce((a, b) => a + b) /
              _subjects.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Review Imported Subjects',
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

                          if (currentSubjects.isNotEmpty) ...[
                            _buildConflictCard(isDark),
                            const SizedBox(height: 24),
                          ],

                          if (_subjects.isEmpty)
                            const Center(
                              child: Text('No subjects found in input'),
                            )
                          else
                            ..._subjects.map(
                              (s) => _buildSubjectCard(s, isDark),
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
                            onPressed: _subjects.isEmpty ? null : _importData,
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
        color: AppColors.redBg.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.redBg.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber, color: AppColors.redBg),
              SizedBox(width: 8),
              Text(
                'Existing Subjects Detected',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.redBg,
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
              'Add new subjects, skip duplicates',
              style: TextStyle(fontSize: 12),
            ),
            value: 'merge',
            groupValue: _conflictMode,
            onChanged: (v) => setState(() => _conflictMode = v!),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.redBg,
          ),
          RadioListTile<String>(
            title: const Text(
              'Start Fresh (DANGER)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text(
              'Deletes all existing subjects AND schedule slots before importing.',
              style: TextStyle(fontSize: 12),
            ),
            value: 'replace',
            groupValue: _conflictMode,
            onChanged: (v) => setState(() => _conflictMode = v!),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.redBg,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(ParsedSubject subject, bool isDark) {
    bool hasWarning =
        subject.confidence < 0.7 ||
        subject.subjectName.toLowerCase() == 'unknown' ||
        subject.subjectName.isEmpty;
    double theoryPct = subject.totalClasses > 0
        ? (subject.attendedClasses / subject.totalClasses) * 100
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242729) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasWarning
              ? AppColors.outlineVariantLight
              : const Color(0xFF4F46E5).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject.subjectName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Icon(
                hasWarning ? Icons.warning_amber : Icons.check_circle,
                color: hasWarning ? AppColors.redBg : const Color(0xFF16A34A),
              ),
            ],
          ),
          if (subject.professor.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Prof: ${subject.professor}',
              style: const TextStyle(
                color: AppColors.outlineLight,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Theory: ${subject.attendedClasses}/${subject.totalClasses} (${theoryPct.toStringAsFixed(1)}%)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subject.hasPractical)
                Text(
                  'Lab: ${subject.practicalAttended}/${subject.practicalTotal}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF006A7C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
