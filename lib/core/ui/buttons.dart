import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';
import 'rast_icon.dart';

/// Coral filled action. Min height 52, radius 30, 15/750 label.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon = 'arrow',
    this.leadingIcon,
    this.minHeight = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? trailingIcon;
  final String? leadingIcon;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    final fg = enabled ? c.onPrimary : c.onPrimaryDisabled;
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedContainer(
        duration: rastButtonDuration,
        curve: rastEase,
        width: double.infinity,
        constraints: BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(
          color: enabled ? c.primary : c.primaryDisabled,
          borderRadius: BorderRadius.circular(30),
          boxShadow: enabled
              ? [BoxShadow(color: c.accent.withValues(alpha: 0.09), blurRadius: 14, offset: const Offset(0, 5))]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leadingIcon != null) ...[
                    RastIcon(leadingIcon!, size: 18, color: fg),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: rastStyle(size: 15, weight: 750, color: fg),
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 10),
                    RastIcon(trailingIcon!, size: 18, color: fg),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined action. Radius 30, 14/700 label.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 14),
          side: BorderSide(color: c.isDark ? const Color(0xFF44434C) : c.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          foregroundColor: c.isDark ? const Color(0xFFE1DCE1) : c.text,
          textStyle: rastStyle(size: 14, weight: 700),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Quiet text action. 13/650, min height 40.
class TextLinkButton extends StatelessWidget {
  const TextLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
    this.color,
    this.size = 13,
    this.underline = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final Color? color;
  final double size;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? (c.isDark ? const Color(0xFFC6C0C8) : const Color(0xFF63636B));
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        foregroundColor: fg,
        textStyle: rastStyle(size: size, weight: 650),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: underline
            ? TextStyle(decoration: TextDecoration.underline, decorationColor: fg)
            : null,
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Round icon button: 36 (header) or 42 default, raised fill.
class IconCircleButton extends StatelessWidget {
  const IconCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 36,
    this.iconSize = 18,
    this.background,
    this.foreground,
    this.border,
  });

  final String icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Material(
            color: background ?? c.raised,
            shape: CircleBorder(side: border != null ? BorderSide(color: border!) : BorderSide.none),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: RastIcon(icon, size: iconSize, color: foreground ?? (c.isDark ? const Color(0xFFD1CCD3) : c.text)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
