import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final double borderRadius;
  final EdgeInsets padding;
  final bool fullWidth;
  final Border? border;

  const CustomButton({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.gradient,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
    this.fullWidth = true,
    this.border,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonContent = Container(
      width: widget.fullWidth ? double.infinity : null,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.gradient == null
            ? (widget.color ?? Theme.of(context).colorScheme.primary)
            : null,
        gradient: widget.gradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.border,
      ),
      child: Center(
        child: DefaultTextStyle(
          style: TextStyle(
            color:
                (widget.color == Colors.transparent ||
                    widget.color == Colors.white)
                ? (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87)
                : Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 15,
            fontFamily: 'Inter',
          ),
          child: widget.child,
        ),
      ),
    );

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: () {
        if (widget.onTap != null) {
          HapticFeedback.lightImpact();
          widget.onTap!();
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: buttonContent,
      ),
    );
  }
}
