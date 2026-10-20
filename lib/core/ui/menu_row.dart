import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';
import 'rast_icon.dart';

/// Icon, label, optional detail, chevron. Bottom divider.
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.detail,
    this.danger = false,
    this.trailing,
  });

  final String label;
  final String icon;
  final VoidCallback onTap;
  final String? detail;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelColor = danger ? (c.isDark ? c.error : c.accent) : (c.isDark ? c.label : const Color(0xFF545460));
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.outline))),
          child: Row(
            children: [
              RastIcon(icon, size: 18, color: c.iconMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: rastStyle(size: 14, weight: 700, color: labelColor)),
                    if (detail != null && detail!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(detail!, style: RastText.menuDetail(c)),
                    ],
                  ],
                ),
              ),
              trailing ??
                  RastIcon('chevron', size: 12, color: c.isDark ? const Color(0xFF9B8A9E) : const Color(0xFFC0C0CA)),
            ],
          ),
        ),
      ),
    );
  }
}
