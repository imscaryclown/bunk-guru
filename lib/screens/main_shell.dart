import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../core/constants/colors.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/schedule/screens/schedule_screen.dart';
import '../features/subjects/screens/subjects_screen.dart';
import '../features/history/screens/calendar_heatmap_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/notifications/services/notification_service.dart';
import '../services/providers.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      const DashboardScreen(),
      const SubjectsScreen(),
      const ScheduleScreen(),
      const CalendarHeatmapScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-schedule notifications every time the app comes to foreground.
      // This ensures the 7-day rolling window of notifications stays fresh.
      NotificationService.rescheduleIfNeeded();
    }
  }

  void _onItemTapped(int index) {
    HapticFeedback.lightImpact();
    ref.read(tabIndexProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = ref.watch(tabIndexProvider);

    final List<Map<String, dynamic>> items = [
      {'icon': Icons.dashboard, 'label': 'HOME'},
      {'icon': Icons.menu_book, 'label': 'SUBJECTS'},
      {'icon': Icons.calendar_month, 'label': 'SCHEDULE'},
      {'icon': Icons.calendar_view_month, 'label': 'CALENDAR'},
      {'icon': Icons.person, 'label': 'PROFILE'},
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgAppDark : AppColors.bgAppLight,
        resizeToAvoidBottomInset: false,
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Screens fill entire space and scroll directly underneath the floating pill
            Positioned.fill(
              child: IndexedStack(index: selectedIndex, children: _screens),
            ),

            // Floating liquid glass pill navbar
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 6,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.12),
                      blurRadius: 28,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDark
                              ? [
                                  const Color(
                                    0xFF1E1E22,
                                  ).withValues(alpha: 0.85),
                                  const Color(
                                    0xFF121214,
                                  ).withValues(alpha: 0.70),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.82),
                                  Colors.white.withValues(alpha: 0.60),
                                ],
                        ),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.75),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(items.length, (index) {
                          final item = items[index];
                          final bool isActive = index == selectedIndex;

                          return GestureDetector(
                            onTap: () => _onItemTapped(index),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              padding: EdgeInsets.symmetric(
                                horizontal: isActive ? 14 : 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? (isDark
                                          ? AppColors.primaryDark.withValues(
                                              alpha: 0.22,
                                            )
                                          : AppColors.primaryLight.withValues(
                                              alpha: 0.12,
                                            ))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 21,
                                    color: isActive
                                        ? (isDark
                                              ? AppColors.primaryDark
                                              : AppColors.primaryLight)
                                        : (isDark
                                              ? AppColors.outlineDark
                                              : AppColors.outlineLight),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['label'] as String,
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: isActive
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      letterSpacing: 0.3,
                                      color: isActive
                                          ? (isDark
                                                ? AppColors.primaryDark
                                                : AppColors.primaryLight)
                                          : (isDark
                                                ? AppColors.outlineDark
                                                : AppColors.outlineLight),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
