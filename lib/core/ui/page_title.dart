import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';

/// Section title under the app header, optional inline badge, subtitle and
/// a right-hand widget. Ends with the standard 20 px gap.
class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.subtitle, this.badge, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Semantics(header: true, child: Text(title, style: RastText.sectionTitle(c))),
                    if (badge != null) ...[const SizedBox(width: Space.s), badge!],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: Space.s),
                  Text(subtitle!, style: RastText.pageSubtitle(c)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
