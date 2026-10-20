import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/appearance.dart';
import '../../../core/theme/rast_colors.dart';
import '../../../core/theme/rast_theme.dart';
import '../../../core/ui/ui.dart';

Future<void> showAppearanceSheet(BuildContext context, WidgetRef ref) {
  return showRastSheet<void>(
    context,
    title: 'Your kind of light.',
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, ref, _) {
        final c = sheetContext.colors;
        final current = ref.watch(appearanceProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Make rast feel right, day or night.', style: rastStyle(size: 13, weight: 450, height: 1.65, color: c.body)),
            const SizedBox(height: 22),
            Semantics(
              label: 'Appearance',
              child: Row(
                children: [
                  for (final a in Appearance.values)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: a == Appearance.system ? 0 : 9),
                        child: _Option(appearance: a, selected: current == a, onTap: () => ref.read(appearanceProvider.notifier).set(a)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('System follows your device. Your choice applies across the app.', style: rastStyle(size: 12, weight: 450, height: 1.7, color: c.body)),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Done', onPressed: () => Navigator.of(sheetContext).pop()),
          ],
        );
      },
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({required this.appearance, required this.selected, required this.onTap});
  final Appearance appearance;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final border = selected ? c.accent : (c.isDark ? const Color(0xFF49434E) : c.outline);
    final bg = selected ? (c.isDark ? const Color(0xFF392924) : const Color(0xFFFFF4EF)) : (c.isDark ? const Color(0xFF24242A) : c.canvas);
    return Semantics(
      button: true,
      selected: selected,
      label: appearanceLabel(appearance),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: border, width: 1.5)),
        child: InkWell(
          key: Key('appearance-${appearance.name}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 13),
            child: Column(
              children: [
                _Preview(appearance: appearance),
                const SizedBox(height: 11),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(appearanceLabel(appearance), style: rastStyle(size: 12, weight: 750, color: c.isDark ? const Color(0xFFE3DCE7) : c.text)),
                    if (selected) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                        child: const Center(child: RastIcon('check', size: 10, color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny mock screen: a card and two dashes, in that theme's colours.
class _Preview extends StatelessWidget {
  const _Preview({required this.appearance});
  final Appearance appearance;

  @override
  Widget build(BuildContext context) {
    final dark = appearance == Appearance.dark;
    final system = appearance == Appearance.system;
    final bg = dark ? const Color(0xFF18191D) : const Color(0xFFF5F4F5);
    final border = dark ? const Color(0xFF3B3B43) : (system ? const Color(0xFFBBB7BB) : const Color(0xFFE6E3E3));
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: system ? null : bg,
        gradient: system ? const LinearGradient(stops: [0.5, 0.5], colors: [Color(0xFFF5F4F5), Color(0xFF18191D)]) : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 11,
            right: 11,
            top: 15,
            height: 36,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: system
                    ? const LinearGradient(stops: [0.5, 0.5], colors: [Color(0xFFEDB7A4), Color(0xFF8C5C4E)])
                    : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: dark ? const [Color(0xFF654640), Color(0xFFB87965)] : const [Color(0xFFF2C1B1), Color(0xFFE8A590)]),
                border: Border.all(color: dark ? const Color(0xFF4D3D39) : (system ? const Color(0xFFA38377) : const Color(0xFFECE8E6))),
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 14,
            child: Row(
              children: [
                Container(width: 22, height: 4, decoration: BoxDecoration(color: dark ? const Color(0xFFFF907F) : const Color(0xFFCF4131), borderRadius: BorderRadius.circular(5))),
                const SizedBox(width: 7),
                Container(width: 22, height: 4, decoration: BoxDecoration(color: dark ? const Color(0xFF505058) : (system ? const Color(0xFF66616A) : const Color(0xFFCBC7C9)), borderRadius: BorderRadius.circular(5))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
