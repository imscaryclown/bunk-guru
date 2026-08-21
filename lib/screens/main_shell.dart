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

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {
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

    return Scaffold(
      // Keep screens alive so they don't rebuild their states when switching tabs
      body: IndexedStack(index: selectedIndex, children: _screens),
      extendBody:
          true, // Allows content to scroll underneath the blurred navigation bar
      bottomNavigationBar: Container(
        height: 84 + MediaQuery.of(context).padding.bottom,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.indigo.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            color: isDark
                ? Colors.black.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.85),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 8,
              top: 10,
              left: 12,
              right: 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final bool isActive = index == selectedIndex;

                return GestureDetector(
                  onTap: () => _onItemTapped(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: isActive ? 12 : 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isDark
                                ? AppColors.primaryDark.withValues(alpha: 0.15)
                                : AppColors.primaryFixed.withValues(alpha: 0.4))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          size: 20,
                          color: isActive
                              ? (isDark
                                    ? AppColors.primaryDark
                                    : AppColors.primaryLight)
                              : (isDark
                                    ? AppColors.outlineDark
                                    : AppColors.outlineLight),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
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
    );
  }
}
