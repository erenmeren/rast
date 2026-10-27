import 'package:flutter/material.dart';

import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';

/// Sub-header, scrolling body and a footer pinned to the bottom.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.headerTitle,
    required this.step,
    required this.body,
    required this.footer,
    this.onBack,
    this.kicker,
    this.headline,
    this.copy,
  });

  final String headerTitle;
  final int step;
  final VoidCallback? onBack;
  final String? kicker;
  final String? headline;
  final String? copy;
  final List<Widget> body;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SubHeader(title: headerTitle, step: step, onBack: onBack),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kicker != null) ...[
                      Text(kicker!, style: RastText.kicker(c)),
                      const SizedBox(height: 6),
                    ],
                    if (headline != null) ...[
                      Semantics(header: true, child: Text(headline!, style: RastText.setupHeadline(c))),
                      const SizedBox(height: 15),
                    ],
                    if (copy != null) Text(copy!, style: rastStyle(size: 13, weight: 450, height: 1.8, color: c.body)),
                    const SizedBox(height: 29),
                    ...body,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xxl),
              child: footer,
            ),
          ],
        ),
      ),
    );
  }
}
