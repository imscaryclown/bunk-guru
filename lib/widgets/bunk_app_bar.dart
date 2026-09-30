import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/colors.dart';

class BunkAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackTap;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final bool showLogo;

  const BunkAppBar({
    super.key,
    this.title = 'Bunk Mitra',
    this.showBackButton = false,
    this.onBackTap,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.showLogo = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1.0);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canPop = Navigator.canPop(context);
    final bool shouldShowBack = showBackButton ||
        (showBackButton == false && leading == null && canPop && title != 'Bunk Mitra');

    Widget? leadingWidget;
    if (leading != null) {
      leadingWidget = Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: leading!,
        ),
      );
    } else if (shouldShowBack) {
      leadingWidget = IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
        onPressed: onBackTap ?? () => Navigator.maybePop(context),
      );
    }

    final bool shouldShowLogo = showLogo && (title == 'Bunk Mitra');

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      titleSpacing: leadingWidget != null ? 10 : 20,
      leadingWidth: leadingWidget != null ? 52 : 0,
      automaticallyImplyLeading: false,
      leading: leadingWidget,
      centerTitle: centerTitle,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (shouldShowLogo) ...[
            Icon(
              Icons.school_rounded,
              size: 24,
              color: isDark ? AppColors.primaryDark : const Color(0xFF4F46E5),
            ),
            const SizedBox(width: 8),
          ],
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFFB4136D)],
            ).createShader(bounds),
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        ...?actions,
        const SizedBox(width: 8),
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
    );
  }
}
