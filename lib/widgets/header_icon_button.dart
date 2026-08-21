import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final double iconSize;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 44.0,
    this.iconSize = 22.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark
        ? const Color(0xFF242238)
        : const Color(0xFFF3F0FD);

    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE4DEF8);

    final Color iconColor = isDark
        ? const Color(0xFFC3C0FF)
        : const Color(0xFF5B4DDF);

    Widget button = Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14.0),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14.0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: iconColor,
            size: iconSize,
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
