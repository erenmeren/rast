import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';
import 'rast_icon.dart';

/// Small status pill. [accent] = peach fill, otherwise outlined.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.accent = false, this.icon, this.dot = false, this.onTap, this.size = 10});

  final String label;
  final bool accent;
  final String? icon;
  final bool dot;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = accent ? (c.isDark ? c.accent : const Color(0xFFD95641)) : (c.isDark ? const Color(0xFFBAB6C0) : c.body);
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent ? c.accentContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        border: accent ? null : Border.all(color: c.isDark ? const Color(0xFF4B4851) : c.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
            ),
          if (icon != null) ...[
            RastIcon(icon!, size: 13, color: fg),
            const SizedBox(width: 6),
          ],
          Text(label, style: rastStyle(size: size, weight: 650, color: fg)),
        ],
      ),
    );
    if (onTap == null) return child;
    return Semantics(
      button: true,
      child: InkWell(borderRadius: BorderRadius.circular(30), onTap: onTap, child: child),
    );
  }
}
