import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';
import 'rast_icon.dart';

/// The "rast." wordmark with the double-circle mark.
class RastLogo extends StatelessWidget {
  const RastLogo({super.key, this.size = 33, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = color ?? c.text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RastIcon('mark', size: size * 22 / 33, color: c.accent),
        SizedBox(width: size * 8 / 33),
        Text.rich(
          TextSpan(
            text: 'rast',
            children: [TextSpan(text: '.', style: TextStyle(color: c.accent))],
          ),
          style: rastStyle(size: size, weight: 800, height: 1, letterSpacing: -2 * size / 33, color: ink),
        ),
      ],
    );
  }
}
