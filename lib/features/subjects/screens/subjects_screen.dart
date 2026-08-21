import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/attendance_math.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../services/providers.dart';
import '../../../services/supabase_service.dart';
import '../../../models/subject.dart';


import '../../../widgets/page_header.dart';
import '../../../widgets/header_icon_button.dart';

class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});

  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
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
    final subjects = ref.watch(subjectProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Header Title =====
            PageHeader(
              title: 'Your Subjects',
              subtitle: 'Track your attendance and manage your bunks wisely.',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HeaderIconButton(
                    icon: Icons.file_download_outlined,
                    tooltip: 'Import Subjects',
                    onTap: () => context.push('/import-subjects'),
                  ),
                  const SizedBox(width: 8),
                  HeaderIconButton(
                    icon: Icons.people_outline_rounded,
                    tooltip: 'Share Subjects',
                    onTap: () => _showShareSheet(),
                  ),
                ],
              ),
            ),

            // ===== Subjects Card List =====
            Expanded(
              child: subjects.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 8.0,
                      ),
                      itemCount: subjects.length,
                      itemBuilder: (context, index) {
                        final s = subjects[index];
                        return _buildSubjectCard(s);
                      },
                    ),
            ),
          ],
        ),
      ),

      // ===== FAB ADD BUTTON =====
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84.0, right: 8.0),
        child: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          onPressed: () => _showAddSubjectSheet(),
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFFB4136D)],
              ),
            ),
            child: const Icon(Icons.add, size: 28),
          ),
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
              color: AppColors.primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.menu_book,
              color: AppColors.primaryContainer,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Subjects Yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap the + button to add your first subject.',
            style: TextStyle(color: AppColors.outlineLight, fontSize: 12),
          ),
        ],
      ).animate().fade(duration: 400.ms),
    );
  }

  Widget _buildSubjectCard(Subject s) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final double theoryPct = AttendanceMath.currentPercent(
      s.attendedClasses,
      s.totalClasses,
    );
    final double practicalPct = s.hasPractical
        ? AttendanceMath.currentPercent(s.practicalAttended, s.practicalTotal)
        : 0.0;

    final int totalA = s.isPracticalOnly
        ? s.practicalAttended
        : (s.attendedClasses + (s.hasPractical ? s.practicalAttended : 0));
    final int totalT = s.isPracticalOnly
        ? s.practicalTotal
        : (s.totalClasses + (s.hasPractical ? s.practicalTotal : 0));
    final double combinedPct = AttendanceMath.currentPercent(totalA, totalT);

    final AttendanceStatus status = AttendanceMath.getStatus(totalA, totalT);
    final String msg = AttendanceMath.getStatusMessage(totalA, totalT);
    final IconData icon = AttendanceMath.getStatusIcon(status);
    final Color cColor = AttendanceMath.getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242729) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: status == AttendanceStatus.danger
              ? AppColors.redBg.withValues(alpha: 0.15)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.outlineVariantLight.withValues(alpha: 0.3)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: cColor.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showEditSubjectSheet(s),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row (Subject name & percentage badge)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.professor.isNotEmpty ? s.professor : 'No Professor',
                          style: const TextStyle(
                            color: AppColors.outlineLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${combinedPct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: cColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.isPracticalOnly
                            ? 'PRACTICAL ONLY'
                            : (s.hasPractical ? 'COMBINED' : 'THEORY ONLY'),
                        style: const TextStyle(
                          color: AppColors.outlineLight,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress bars
              if (!s.isPracticalOnly) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'THEORY',
                          style: TextStyle(
                            color: AppColors.outlineLight,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${theoryPct.toStringAsFixed(1)}% (${s.attendedClasses}/${s.totalClasses})',
                          style: const TextStyle(
                            color: AppColors.outlineLight,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: theoryPct / 100,
                      backgroundColor: isDark
                          ? const Color(0xFF282C2F)
                          : AppColors.bgSurfaceContainerLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryLight,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 5,
                    ),
                  ],
                ),
              ],

              if (s.hasPractical) ...[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PRACTICAL / LAB',
                          style: TextStyle(
                            color: AppColors.outlineLight,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${practicalPct.toStringAsFixed(1)}% (${s.practicalAttended}/${s.practicalTotal})',
                          style: const TextStyle(
                            color: AppColors.outlineLight,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: practicalPct / 100,
                      backgroundColor: isDark
                          ? const Color(0xFF282C2F)
                          : AppColors.bgSurfaceContainerLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF006A7C),
                      ),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 5,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Bottom status verdict strip
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: status == AttendanceStatus.danger
                      ? AppColors.redBg.withValues(alpha: 0.06)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : AppColors.bgSurfaceLowLight),
                  border: Border.all(
                    color: status == AttendanceStatus.danger
                        ? AppColors.redBg.withValues(alpha: 0.1)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppColors.outlineVariantLight.withValues(
                                  alpha: 0.15,
                                )),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: cColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        msg,
                        style: TextStyle(
                          color: status == AttendanceStatus.danger
                              ? AppColors.redBg
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
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
  }

  // ===== BOTTOM SHEETS FOR SUBJECTS ACTIONS =====

  void _showAddSubjectSheet() {
    final nameController = TextEditingController();
    final professorController = TextEditingController();
    final totalController = TextEditingController(text: '0');
    final attendedController = TextEditingController(text: '0');
    final practicalTotalController = TextEditingController(text: '0');
    final practicalAttendedController = TextEditingController(text: '0');

    bool hasPractical = false;
    bool isPracticalOnly = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1D2022)
                    : const Color(0xFFFFFFFF),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                  const Text(
                    'Add Subject',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: nameController,
                    hintText: 'Subject name',
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: professorController,
                    hintText: 'Professor name',
                  ),
                  const SizedBox(height: 12),

                  // Theory Counts Grid
                  if (!isPracticalOnly) ...[
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: totalController,
                            hintText: '0',
                            labelText: 'TOTAL CLASSES',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            controller: attendedController,
                            hintText: '0',
                            labelText: 'ATTENDED',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Has Lab Checkbox Box
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.02)
                          : AppColors.bgSurfaceLowLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.outlineVariantLight.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: hasPractical,
                          activeColor: AppColors.primaryLight,
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                hasPractical = val;
                              });
                            }
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Subject has Practical / Lab?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Is Lab Only Checkbox Box
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF006A7C).withValues(alpha: 0.1)
                          : const Color(0x13006A7C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF006A7C).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isPracticalOnly,
                          activeColor: const Color(0xFF006A7C),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                isPracticalOnly = val;
                                if (val) {
                                  hasPractical = true; // Auto enable lab fields
                                }
                              });
                            }
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Only Practical / Lab Subject?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lab fields
                  if (hasPractical) ...[
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: practicalTotalController,
                            hintText: '0',
                            labelText: 'LAB TOTAL',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            controller: practicalAttendedController,
                            hintText: '0',
                            labelText: 'LAB ATTENDED',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Submit button
                  CustomButton(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFFB4136D)],
                    ),
                    onTap: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;

                      await ref
                          .read(subjectProvider.notifier)
                          .add(
                            name: name,
                            professor: professorController.text.trim(),
                            totalClasses: isPracticalOnly
                                ? 0
                                : int.parse(
                                    totalController.text.isEmpty
                                        ? '0'
                                        : totalController.text,
                                  ),
                            attendedClasses: isPracticalOnly
                                ? 0
                                : int.parse(
                                    attendedController.text.isEmpty
                                        ? '0'
                                        : attendedController.text,
                                  ),
                            hasPractical: hasPractical,
                            isPracticalOnly: isPracticalOnly,
                            practicalTotal: int.parse(
                              practicalTotalController.text.isEmpty
                                  ? '0'
                                  : practicalTotalController.text,
                            ),
                            practicalAttended: int.parse(
                              practicalAttendedController.text.isEmpty
                                  ? '0'
                                  : practicalAttendedController.text,
                            ),
                          );

                      if (mounted) {
                        Navigator.pop(context);
                        _toast('Subject added!', true);
                      }
                    },
                    child: const Text(
                      'ADD SUBJECT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditSubjectSheet(Subject s) {
    final nameController = TextEditingController(text: s.name);
    final professorController = TextEditingController(text: s.professor);

    int total = s.totalClasses;
    int attended = s.attendedClasses;
    int practicalTotal = s.practicalTotal;
    int practicalAttended = s.practicalAttended;
    bool hasPractical = s.hasPractical;
    bool isPracticalOnly = s.isPracticalOnly;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Re-run simulator logic on change
            final int tA = isPracticalOnly
                ? practicalAttended
                : (attended + (hasPractical ? practicalAttended : 0));
            final int tT = isPracticalOnly
                ? practicalTotal
                : (total + (hasPractical ? practicalTotal : 0));
            final double simPct = AttendanceMath.currentPercent(tA, tT);
            final String simMsg = AttendanceMath.getStatusMessage(tA, tT);

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1D2022)
                    : const Color(0xFFFFFFFF),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                    'Edit Subject — ${s.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: nameController,
                    hintText: 'Subject name',
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: professorController,
                    hintText: 'Professor name',
                  ),
                  const SizedBox(height: 12),

                  // Theory counter
                  if (!isPracticalOnly) ...[
                    Row(
                      children: [
                        // Total Classes Increment
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL CLASSES',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.outlineLight,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildCounterBtn(
                                    '-',
                                    () => setModalState(
                                      () => total = max(0, total - 1),
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        '$total',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildCounterBtn(
                                    '+',
                                    () =>
                                        setModalState(() => total = total + 1),
                                    isAdd: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Attended Classes Increment
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ATTENDED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.outlineLight,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildCounterBtn(
                                    '-',
                                    () => setModalState(
                                      () => attended = max(0, attended - 1),
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        '$attended',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildCounterBtn(
                                    '+',
                                    () => setModalState(
                                      () => attended = attended + 1,
                                    ),
                                    isAdd: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Has Practical checkbox
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.02)
                          : AppColors.bgSurfaceLowLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.outlineVariantLight.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: hasPractical,
                          activeColor: AppColors.primaryLight,
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                hasPractical = val;
                              });
                            }
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Subject has Practical / Lab?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Is Practical only checkbox
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF006A7C).withValues(alpha: 0.1)
                          : const Color(0x13006A7C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF006A7C).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isPracticalOnly,
                          activeColor: const Color(0xFF006A7C),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                isPracticalOnly = val;
                                if (val) hasPractical = true;
                              });
                            }
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Only Practical / Lab Subject?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lab Counters
                  if (hasPractical) ...[
                    Row(
                      children: [
                        // Lab Total
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LAB TOTAL',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.outlineLight,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildCounterBtn(
                                    '-',
                                    () => setModalState(
                                      () => practicalTotal = max(
                                        0,
                                        practicalTotal - 1,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        '$practicalTotal',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildCounterBtn(
                                    '+',
                                    () => setModalState(
                                      () => practicalTotal = practicalTotal + 1,
                                    ),
                                    isAdd: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Lab Attended
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LAB ATTENDED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.outlineLight,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildCounterBtn(
                                    '-',
                                    () => setModalState(
                                      () => practicalAttended = max(
                                        0,
                                        practicalAttended - 1,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        '$practicalAttended',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildCounterBtn(
                                    '+',
                                    () => setModalState(
                                      () => practicalAttended =
                                          practicalAttended + 1,
                                    ),
                                    isAdd: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Live simulated preview block
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF282C2F)
                          : AppColors.bgSurfaceContainerLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${isPracticalOnly ? "Practical" : "Combined"}: ${simPct.toStringAsFixed(1)}% — $simMsg',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save & Delete buttons row
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
                                title: const Text('Delete Subject?'),
                                content: const Text(
                                  'Are you sure you want to remove this subject? This will delete all its schedule entries and check-ins.',
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
                                  .read(subjectProvider.notifier)
                                  .delete(s.id);
                              if (mounted) {
                                Navigator.pop(context);
                                _toast('Subject deleted', false);
                              }
                            }
                          },
                          child: const Text(
                            'DELETE',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: CustomButton(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFFB4136D)],
                          ),
                          onTap: () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;

                            await ref
                                .read(subjectProvider.notifier)
                                .update(s.id, {
                                  'name': name,
                                  'professor': professorController.text.trim(),
                                  'total_classes': isPracticalOnly ? 0 : total,
                                  'attended_classes': isPracticalOnly
                                      ? 0
                                      : attended,
                                  'has_practical': hasPractical,
                                  'is_practical_only': isPracticalOnly,
                                  'practical_total': practicalTotal,
                                  'practical_attended': practicalAttended,
                                  'icon': s.icon,
                                  'color': s.color,
                                });

                            if (mounted) {
                              Navigator.pop(context);
                              _toast('Subject updated!', true);
                            }
                          },
                          child: const Text(
                            'SAVE CHANGES',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1D2022)
                    : const Color(0xFFFFFFFF),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                  const Text(
                    'Batch Schedule',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            fontWeight: FontWeight.bold,
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
                                  fontWeight: FontWeight.bold,
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

                                    if (context.mounted) {
                                      Navigator.pop(
                                        context,
                                      ); // Close share sheet
                                      _showSyncSheet(
                                        subjectsJson,
                                        scheduleJson,
                                      ); // Open sync sheet!
                                    }
                                  } catch (e) {
                                    _toast('Failed to load code: $e', false);
                                  }
                                },
                                child: const Text(
                                  'LOAD',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
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
                            fontWeight: FontWeight.bold,
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
                                      fontWeight: FontWeight.bold,
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
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  generatedCode,
                                  style: const TextStyle(
                                    color: AppColors.primaryLight,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
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
            );
          },
        );
      },
    );
  }

  void _showSyncSheet(List<dynamic> subjectsJson, List<dynamic> scheduleJson) {
    // Clone subjects list to hold mutable state
    final List<Map<String, dynamic>> syncList = List.from(
      subjectsJson.map((s) => Map<String, dynamic>.from(s as Map)),
    );

    // Track state: Map for theory and practical attended counts
    final Map<String, int> theoryCounts = {};
    final Map<String, int> practicalCounts = {};

    for (final s in syncList) {
      final String id = s['id'] as String;
      // Start with total classes as attended (same as Capacitor app)
      theoryCounts[id] = s['total_classes'] as int? ?? 0;
      practicalCounts[id] = s['practical_total'] as int? ?? 0;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1D2022) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
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
                        color: isDark ? Colors.white30 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sync Attendance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'How many of these classes have you attended so far?',
                    style: TextStyle(
                      color: AppColors.outlineLight,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Scrollable List of Subjects
                  Expanded(
                    child: ListView.builder(
                      itemCount: syncList.length,
                      itemBuilder: (context, index) {
                        final s = syncList[index];
                        final String id = s['id'] as String;
                        final String name = s['name'] as String? ?? 'Subject';
                        final bool hasPractical =
                            s['has_practical'] as bool? ?? false;
                        final bool isPracticalOnly =
                            s['is_practical_only'] as bool? ?? false;
                        final int theoryTotal = s['total_classes'] as int? ?? 0;
                        final int practicalTotal =
                            s['practical_total'] as int? ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF242729)
                                : AppColors.bgSurfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : AppColors.outlineVariantLight.withValues(
                                      alpha: 0.3,
                                    ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Theory row
                              if (!isPracticalOnly) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Theory Classes',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '$theoryTotal Held',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.outlineLight,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        _buildCounterBtn('-', () {
                                          setModalState(() {
                                            theoryCounts[id] = max(
                                              0,
                                              (theoryCounts[id] ?? 0) - 1,
                                            );
                                          });
                                        }),
                                        SizedBox(
                                          width: 38,
                                          child: Center(
                                            child: Text(
                                              '${theoryCounts[id] ?? 0}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        _buildCounterBtn('+', () {
                                          setModalState(() {
                                            theoryCounts[id] = min(
                                              theoryTotal,
                                              (theoryCounts[id] ?? 0) + 1,
                                            );
                                          });
                                        }, isAdd: true),
                                      ],
                                    ),
                                  ],
                                ),
                              ],

                              // Practical / Lab Row
                              if (hasPractical) ...[
                                if (!isPracticalOnly)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Divider(
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.black12,
                                      height: 1,
                                    ),
                                  ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Practical / Lab',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF006A7C),
                                          ),
                                        ),
                                        Text(
                                          '$practicalTotal Held',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.outlineLight,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        _buildCounterBtn('-', () {
                                          setModalState(() {
                                            practicalCounts[id] = max(
                                              0,
                                              (practicalCounts[id] ?? 0) - 1,
                                            );
                                          });
                                        }),
                                        SizedBox(
                                          width: 38,
                                          child: Center(
                                            child: Text(
                                              '${practicalCounts[id] ?? 0}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        _buildCounterBtn('+', () {
                                          setModalState(() {
                                            practicalCounts[id] = min(
                                              practicalTotal,
                                              (practicalCounts[id] ?? 0) + 1,
                                            );
                                          });
                                        }, isAdd: true),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Commit Sync Button
                  CustomButton(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFFB4136D)],
                    ),
                    onTap: () async {
                      try {
                        // Map counts back
                        final List<dynamic> updatedSubjects = syncList.map((s) {
                          final String id = s['id'] as String;
                          return {
                            ...s,
                            'attended_classes': theoryCounts[id] ?? 0,
                            'practical_attended': practicalCounts[id] ?? 0,
                          };
                        }).toList();

                        await SupabaseService.commitSharedData(
                          updatedSubjects,
                          scheduleJson,
                        );

                        ref.read(subjectProvider.notifier).refresh();
                        ref.read(scheduleProvider.notifier).refresh();

                        if (context.mounted) {
                          Navigator.pop(context); // Close sync sheet
                          _toast('Batch joined successfully! 🎉', true);
                        }
                      } catch (e) {
                        _toast('Failed to join batch: $e', false);
                      }
                    },
                    child: const Text(
                      'LOAD DATA AND FINISH',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCounterBtn(
    String symbol,
    VoidCallback onTap, {
    bool isAdd = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bg = isAdd
        ? (isDark
              ? AppColors.primaryDark.withValues(alpha: 0.1)
              : AppColors.primaryFixed)
        : (isDark
              ? Colors.white.withValues(alpha: 0.04)
              : AppColors.bgSurfaceContainerLight);

    final Color fg = isAdd
        ? AppColors.primaryLight
        : (isDark ? Colors.white70 : Colors.black87);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Center(
          child: Text(
            symbol,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ),
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
}
