import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';
import 'rast_icon.dart';

/// Warm peach box with an icon, bold lead and body text.
class InfoBox extends StatelessWidget {
  const InfoBox({super.key, required this.icon, required this.strong, required this.text});

  final String icon;
  final String strong;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = c.isDark ? const Color(0xFF302621) : const Color(0xFFFFF3EE);
    final body = c.isDark ? const Color(0xFFD7B4A5) : const Color(0xFF855949);
    final lead = c.isDark ? const Color(0xFFF0C8B8) : const Color(0xFF855949);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: RastIcon(icon, size: 17, color: c.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strong, style: rastStyle(size: 12, weight: 750, color: lead)),
                const SizedBox(height: 3),
                Text(text, style: rastStyle(size: 12, weight: 450, height: 1.7, color: body)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Smaller tip strip used in settings and sheets.
class SettingTip extends StatelessWidget {
  const SettingTip({super.key, required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = c.isDark ? const Color(0xFF302621) : const Color(0xFFFFF3EE);
    final fg = c.isDark ? const Color(0xFFD7B4A5) : const Color(0xFF966A56);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: RastIcon(icon, size: 13, color: c.accent),
          ),
          const SizedBox(width: 7),
          Expanded(child: Text(text, style: rastStyle(size: 12, weight: 450, height: 1.8, color: fg))),
        ],
      ),
    );
  }
}

/// An icon + bold title + body row with a bottom divider (permission items).
class FeatureItem extends StatelessWidget {
  const FeatureItem({super.key, required this.icon, required this.title, required this.text, this.divider = true});

  final String icon;
  final String title;
  final String text;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: divider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: c.outline)))
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: RastIcon(icon, size: 19, color: c.accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: rastStyle(size: 14, weight: 750, color: c.isDark ? c.label : const Color(0xFF52525D))),
                const SizedBox(height: 5),
                Text(text, style: rastStyle(size: 12, weight: 450, height: 1.65, color: c.isDark ? c.body : const Color(0xFF73737F))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
