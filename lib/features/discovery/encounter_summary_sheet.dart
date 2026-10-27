import 'package:flutter/material.dart';

import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';

/// Compact three-step explanation. The animated page is the primary route;
/// this stays available as a lightweight summary.
Future<void> showEncounterSummarySheet(BuildContext context) {
  return showRastSheet<void>(
    context,
    title: 'Real-life crossings.',
    builder: (sheetContext) {
      final c = sheetContext.colors;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 137,
            margin: const EdgeInsets.symmetric(vertical: 19),
            decoration: BoxDecoration(
              color: c.accentContainer,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: c.isDark ? const Color(0xFF79553F) : const Color(0xFFFFE4D6)),
            ),
            child: Stack(
              children: [
                Positioned(left: 0, right: 0, top: 13, child: Center(child: Transform.translate(offset: const Offset(-22, 0), child: _ring(c.isDark ? const Color(0xFFB78461) : const Color(0xFFFFC6B0), null)))),
                Positioned(left: 0, right: 0, top: 13, child: Center(child: Transform.translate(offset: const Offset(23, 0), child: _ring(c.isDark ? const Color(0xFFEB9D6D) : const Color(0xFFFA9876), c.isDark ? const Color(0x2AA76735) : const Color(0x55FFE6DA))))),
                Positioned(left: 0, right: 0, top: 63, child: Center(child: Transform.translate(offset: const Offset(-23, 0), child: _dot(c.accent)))),
                Positioned(left: 0, right: 0, top: 63, child: Center(child: Transform.translate(offset: const Offset(23, 0), child: _dot(c.accent)))),
                Positioned(left: 0, right: 0, top: 51, child: Center(child: Text('20 m', style: rastStyle(size: 9, weight: 700, color: c.accent)))),
                Positioned(left: 15, bottom: 12, child: Text('ILLUSTRATIVE PROXIMITY', style: rastStyle(size: 8, weight: 650, letterSpacing: 0.5, color: c.isDark ? const Color(0xFFD0AC8B) : const Color(0xFFCFA798)))),
              ],
            ),
          ),
          const FeatureItem(icon: 'mark', title: 'Your paths cross.', text: "Location readings suggest you were within about 20 metres and you both meet each other's preferences."),
          const FeatureItem(icon: 'clock', title: 'A little time passes.', text: 'The default is 2 hours. The longer of your two privacy delays applies, including on Likes You.'),
          const FeatureItem(icon: 'heart', title: 'Two likes. One connection.', text: 'When you both like, you can chat. Matching in Discover stays free.', divider: false),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Got it', onPressed: () => Navigator.of(sheetContext).pop()),
        ],
      );
    },
  );
}

Widget _ring(Color border, Color? fill) => Container(
      width: 109,
      height: 109,
      decoration: BoxDecoration(shape: BoxShape.circle, color: fill, border: Border.all(color: border)),
    );

Widget _dot(Color color) => Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
