import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/attendance_math.dart';
import '../../../services/providers.dart';
import '../../../models/subject.dart';
import '../../../widgets/header_icon_button.dart';
import '../../../widgets/page_header.dart';

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  String? _selectedSubjectId;
  double _bunkCount = 0.0;
  double _attendCount = 0.0;

  @override
  void initState() {
    super.initState();
    // Auto-select first subject if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final subs = ref.read(subjectProvider);
      if (subs.isNotEmpty) {
        setState(() {
          _selectedSubjectId = subs.first.id;
        });
      }
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        backgroundColor: AppColors.primaryContainer,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
        margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final subjects = ref.watch(subjectProvider);

    final Subject? activeSubject = _selectedSubjectId != null
        ? subjects.firstWhere(
            (sub) => sub.id == _selectedSubjectId,
            orElse: () => subjects.first,
          )
        : null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 16.0,
          ),
          children: [
            // ===== 1. Page Header =====
            PageHeader(
              title: 'Bunk Calculator',
              subtitle:
                  'Simulate how bunking or attending affects your %.',
              padding: const EdgeInsets.only(bottom: 24.0),
              trailing: Navigator.canPop(context)
                  ? HeaderIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.maybePop(context),
                    )
                  : null,
            ),

            if (subjects.isEmpty)
              _buildEmptyState()
            else ...[
              // ===== 2. Subject Chips Selector Strip =====
                  const Row(
                    children: [
                      Icon(
                        Icons.school,
                        color: AppColors.primaryLight,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Select Subject',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 42,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: subjects.length,
                      itemBuilder: (context, index) {
                        final s = subjects[index];
                        final bool isActive = s.id == _selectedSubjectId;

                        final int totalA = s.isPracticalOnly
                            ? s.practicalAttended
                            : (s.attendedClasses +
                                  (s.hasPractical ? s.practicalAttended : 0));
                        final int totalT = s.isPracticalOnly
                            ? s.practicalTotal
                            : (s.totalClasses +
                                  (s.hasPractical ? s.practicalTotal : 0));
                        final double pct = AttendanceMath.currentPercent(
                          totalA,
                          totalT,
                        );
                        final AttendanceStatus status =
                            AttendanceMath.getStatus(totalA, totalT);

                        final Color dotColor = AttendanceMath.getStatusColor(
                          status,
                        );

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedSubjectId = s.id;
                              _bunkCount = 0.0;
                              _attendCount = 0.0;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8.0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primaryLight.withValues(
                                      alpha: 0.08,
                                    )
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : AppColors.bgSurfaceContainerLight
                                              .withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive
                                    ? AppColors.primaryLight
                                    : (isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : AppColors.outlineVariantLight
                                                .withValues(alpha: 0.3)),
                                width: isActive ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  s.name,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? AppColors.primaryLight
                                        : (isDark
                                              ? AppColors.textMainDark
                                              : AppColors.textMainLight),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${pct.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: AppColors.outlineLight,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (activeSubject != null) ...[
                    // ===== 3. Active Subject Stats Card =====
                    _buildActiveSubjectCard(activeSubject),
                    const SizedBox(height: 20),

                    // ===== 4. Dual Sliders Ranges =====
                    _buildSlidersBlock(),
                    const SizedBox(height: 20),

                    // ===== 5. Predicted Result Card =====
                    _buildResultCard(activeSubject),
                    const SizedBox(height: 20),

                    // ===== 6. Quick Scenarios Grid =====
                    _buildScenariosBlock(),
                  ],
                ],
              ],
            ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 48.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0x13EDFF00),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.menu_book,
                color: Color(0xFF00505F),
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
              'Add subjects first to use the simulator.',
              style: TextStyle(color: AppColors.outlineLight, fontSize: 12),
            ),
          ],
        ).animate().fade(duration: 400.ms),
      ),
    );
  }

  Widget _buildActiveSubjectCard(Subject s) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final int attended = s.isPracticalOnly
        ? s.practicalAttended
        : (s.attendedClasses + (s.hasPractical ? s.practicalAttended : 0));
    final int total = s.isPracticalOnly
        ? s.practicalTotal
        : (s.totalClasses + (s.hasPractical ? s.practicalTotal : 0));
    final double pct = AttendanceMath.currentPercent(attended, total);
    final AttendanceStatus status = AttendanceMath.getStatus(attended, total);

    final Color statusColor = AttendanceMath.getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.professor.isNotEmpty ? s.professor : 'No Professor'} · ${s.isPracticalOnly ? 'Practical Only' : (s.hasPractical ? 'Theory + Lab' : 'Theory')}',
                      style: const TextStyle(
                        color: AppColors.outlineLight,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: isDark
                ? Colors.white10
                : Colors.indigo.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 12),

          // Current Counts Bento Box Row
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        color: AppColors.outlineLight,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: isDark
                    ? Colors.white10
                    : Colors.indigo.withValues(alpha: 0.05),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'PRESENT',
                      style: TextStyle(
                        color: AppColors.outlineLight,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$attended',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: isDark
                    ? Colors.white10
                    : Colors.indigo.withValues(alpha: 0.05),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'MISSED',
                      style: TextStyle(
                        color: AppColors.outlineLight,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${total - attended}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlidersBlock() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bunk Slider
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.redBg.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.flight_takeoff,
                  color: AppColors.redBg,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'IF I BUNK NEXT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.outlineLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _bunkCount,
                  min: 0,
                  max: 20,
                  divisions: 20,
                  activeColor: AppColors.redBg,
                  inactiveColor: isDark
                      ? Colors.white10
                      : Colors.indigo.withValues(alpha: 0.05),
                  onChanged: (val) {
                    setState(() {
                      _bunkCount = val;
                    });
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.redBg.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_bunkCount.toInt()}',
                  style: const TextStyle(
                    color: AppColors.redBg,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: isDark
                ? Colors.white10
                : Colors.indigo.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 16),

          // Attend Slider
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF16A34A),
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AND ATTEND NEXT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.outlineLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _attendCount,
                  min: 0,
                  max: 20,
                  divisions: 20,
                  activeColor: const Color(0xFF16A34A),
                  inactiveColor: isDark
                      ? Colors.white10
                      : Colors.indigo.withValues(alpha: 0.05),
                  onChanged: (val) {
                    setState(() {
                      _attendCount = val;
                    });
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_attendCount.toInt()}',
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Subject s) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final int attended = s.isPracticalOnly
        ? s.practicalAttended
        : (s.attendedClasses + (s.hasPractical ? s.practicalAttended : 0));
    final int total = s.isPracticalOnly
        ? s.practicalTotal
        : (s.totalClasses + (s.hasPractical ? s.practicalTotal : 0));

    final double currentPct = AttendanceMath.currentPercent(attended, total);

    // Calculate predictions
    final int b = _bunkCount.toInt();
    final int a = _attendCount.toInt();

    final int newTotal = total + b + a;
    final int newAttended = attended + a;

    final double newPct = newTotal > 0 ? (newAttended / newTotal) * 100 : 0.0;
    final double diff = newPct - currentPct;

    final AttendanceStatus newStatus = AttendanceMath.getStatus(
      newAttended,
      newTotal,
    );
    final int safeBunks = AttendanceMath.safeBunks(newAttended, newTotal);
    final int needed = AttendanceMath.requiredClasses(newAttended, newTotal);

    // Card styling
    Color bg;
    Color border;
    Color iconBg;
    Color iconColor;
    IconData icon;

    switch (newStatus) {
      case AttendanceStatus.danger:
        bg = isDark
            ? const Color(0xFF2E1C1D)
            : const Color(0xFFFFDAD6).withValues(alpha: 0.5);
        border = AppColors.redBg.withValues(alpha: 0.2);
        iconBg = const Color(0xFFFFDAD6);
        iconColor = AppColors.redBg;
        icon = Icons.warning;
        break;
      case AttendanceStatus.warning:
        bg = isDark
            ? const Color(0xFF2E2C1D)
            : const Color(0xFFFEF9C3).withValues(alpha: 0.5);
        border = AppColors.yellowBg.withValues(alpha: 0.2);
        iconBg = const Color(0xFFFEF9C3);
        iconColor = AppColors.yellowText;
        icon = Icons.info;
        break;
      case AttendanceStatus.safe:
        bg = isDark
            ? const Color(0xFF1C2E1F)
            : const Color(0xFFDCFCE7).withValues(alpha: 0.5);
        border = const Color(0xFF22C55E).withValues(alpha: 0.2);
        iconBg = const Color(0xFFDCFCE7);
        iconColor = const Color(0xFF16A34A);
        icon = Icons.check_circle;
        break;
    }

    final diffStr = diff >= 0
        ? '+${diff.toStringAsFixed(2)}%'
        : '${diff.toStringAsFixed(2)}%';
    final Color diffColor = diff >= 0
        ? const Color(0xFF16A34A)
        : AppColors.redBg;

    String verdictText;
    String verdictEmoji;
    switch (newStatus) {
      case AttendanceStatus.danger:
        verdictEmoji = '🚨';
        verdictText = needed > 0
            ? 'Attend $needed more class${needed != 1 ? 'es' : ''} after this to reach 75%'
            : 'Below 75% — debar risk!';
        break;
      case AttendanceStatus.warning:
        verdictEmoji = '⚠️';
        verdictText =
            'Cutting it close! One more miss could push you below 75%';
        break;
      case AttendanceStatus.safe:
        verdictEmoji = safeBunks > 3 ? '😎' : '✅';
        verdictText =
            'You\'ll still have $safeBunks safe bunk${safeBunks != 1 ? 's' : ''} remaining';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Predicted Result',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'AFTER SIMULATING SLIDER CHANGES',
                    style: TextStyle(
                      color: AppColors.outlineLight,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NEW ATTENDANCE',
                    style: TextStyle(
                      color: AppColors.outlineLight,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${newPct.toStringAsFixed(2)}%',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'CHANGE',
                    style: TextStyle(
                      color: AppColors.outlineLight,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    diffStr,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: diffColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linear animated-like progress bar
          LinearProgressIndicator(
            value: newPct / 100,
            backgroundColor: isDark
                ? Colors.white10
                : Colors.indigo.withValues(alpha: 0.05),
            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
          const SizedBox(height: 12),

          // Verdict banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(verdictEmoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    verdictText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$newAttended/$newTotal classes',
                style: const TextStyle(
                  color: AppColors.outlineLight,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: newPct >= 75.0
                          ? const Color(0xFF22C55E)
                          : AppColors.redBg,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    newPct >= 75.0 ? 'Above 75%' : 'Below 75%',
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
        ],
      ),
    );
  }

  Widget _buildScenariosBlock() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Map<String, dynamic>> scenarios = [
      {
        'emoji': '😴',
        'title': 'Skip 1 class',
        'sub': 'Just one day off',
        'bunk': 1.0,
        'attend': 0.0,
      },
      {
        'emoji': '🏖️',
        'title': 'Skip 3 classes',
        'sub': 'Mini vacation',
        'bunk': 3.0,
        'attend': 0.0,
      },
      {
        'emoji': '💀',
        'title': 'Skip 5 classes',
        'sub': 'Living dangerously',
        'bunk': 5.0,
        'attend': 0.0,
      },
      {
        'emoji': '📚',
        'title': 'Attend 5 more',
        'sub': 'Recovery mode',
        'bunk': 0.0,
        'attend': 5.0,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.bolt, color: AppColors.primaryLight, size: 16),
            SizedBox(width: 8),
            Text(
              'Quick Scenarios',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: scenarios.map((s) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _bunkCount = s['bunk'] as double;
                  _attendCount = s['attend'] as double;
                });
                _toast(
                  'Configured: Skip ${_bunkCount.toInt()} & Attend ${_attendCount.toInt()} class${_attendCount.toInt() != 1 || _bunkCount.toInt() != 1 ? 'es' : ''}',
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF242729)
                      : const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : AppColors.outlineVariantLight.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['emoji'] as String,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    Text(
                      s['title'] as String,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      s['sub'] as String,
                      style: const TextStyle(
                        color: AppColors.outlineLight,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
