import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';

/// Four-column grid of selectable timing choices (8 values).
class TimingGrid<T> extends StatelessWidget {
  const TimingGrid({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelect,
    this.note,
    this.minHeight = 44,
    this.semanticLabel,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final String? Function(T)? note;
  final ValueChanged<T> onSelect;
  final double minHeight;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: c.isDark ? const Color(0xFF222329) : const Color(0xFFF4F4F7),
          borderRadius: BorderRadius.circular(13),
          border: c.isDark ? Border.all(color: const Color(0xFF303038)) : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 5.0;
            final cell = (constraints.maxWidth - gap * 3) / 4;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final v in values)
                  SizedBox(
                    width: cell,
                    child: _Cell<T>(
                      value: v,
                      selected: v == selected,
                      label: label(v),
                      note: note?.call(v),
                      minHeight: minHeight,
                      onTap: () => onSelect(v),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Cell<T> extends StatelessWidget {
  const _Cell({required this.value, required this.selected, required this.label, required this.note, required this.minHeight, required this.onTap});
  final T value;
  final bool selected;
  final String label;
  final String? note;
  final double minHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? Colors.white : (c.isDark ? const Color(0xFFBBB4C1) : const Color(0xFF777783));
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? c.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        elevation: selected ? 2 : 0,
        shadowColor: c.accent.withValues(alpha: 0.3),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, textAlign: TextAlign.center, style: rastStyle(size: 13, weight: 650, height: 1.3, color: fg)),
                  if (note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        note!.isEmpty ? ' ' : note!,
                        textAlign: TextAlign.center,
                        style: rastStyle(size: 8, weight: 650, letterSpacing: -0.15, height: 1.3, color: fg.withValues(alpha: selected ? 0.9 : 0.75)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
