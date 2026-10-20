import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';
import 'rast_icon.dart';

/// Selectable pill with a check mark when selected. Min height 44.
class OptionChip extends StatelessWidget {
  const OptionChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final border = selected ? c.accent : (c.isDark ? const Color(0xFF45424C) : const Color(0xFFE7E7EC));
    final bg = selected ? c.accentContainer : (c.isDark ? const Color(0xFF212228) : c.canvas);
    final fg = selected ? c.onAccentContainer : (c.isDark ? const Color(0xFFC3BEC8) : const Color(0xFF64646F));
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: rastStyle(size: 13, weight: 650, color: fg)),
                  if (selected) ...[
                    const SizedBox(width: 7),
                    RastIcon('check', size: 13, color: c.accent),
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

/// Wrapping group of chips, 8px gaps.
class OptionGroup extends StatelessWidget {
  const OptionGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: children);
}
