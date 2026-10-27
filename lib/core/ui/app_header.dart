import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';
import 'buttons.dart';
import 'header_bar.dart';
import 'rast_logo.dart';

/// Logo on the left, optional PLUS mini tag and one action button on the right.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.action,
    required this.onAction,
    this.premium = false,
  });

  /// `filters` (sliders icon, "Dating preferences") or `settings` (clock icon, "Location settings").
  final String action;
  final VoidCallback onAction;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isFilters = action == 'filters';
    return HeaderBar(
      leading: const HeaderInset(child: RastLogo(size: RastLogo.headerSize)),
      trailing: Row(
        children: [
          if (premium)
            Container(
              margin: const EdgeInsets.only(right: Space.s),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              decoration: BoxDecoration(
                color: c.isDark ? c.accentContainer : const Color(0xFFFFEBE4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'PLUS',
                style: rastStyle(size: 8, weight: 800, letterSpacing: 1, color: c.isDark ? c.accent : const Color(0xFFD6533E)),
              ),
            ),
          IconCircleButton(
            icon: isFilters ? 'sliders' : 'clock',
            onPressed: onAction,
            semanticLabel: isFilters ? 'Dating preferences' : 'Location settings',
          ),
        ],
      ),
    );
  }
}
