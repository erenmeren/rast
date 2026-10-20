import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';
import 'buttons.dart';
import 'rast_icon.dart';

/// Centred orbit illustration, headline, copy and optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String icon;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ring = c.isDark ? const Color(0xFF955B4D) : const Color(0xFFFFCABB);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 116,
              height: 86,
              child: Stack(
                children: [
                  Positioned(
                    left: 38,
                    top: 0,
                    child: Container(
                      width: 77,
                      height: 77,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c.accentContainer, border: Border.all(color: ring)),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 77,
                      height: 77,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring)),
                    ),
                  ),
                  Center(child: RastIcon(icon, size: 22, color: c.accent)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: Text(title, textAlign: TextAlign.center, style: RastText.emptyTitle(c)),
            ),
            const SizedBox(height: 11),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(text, textAlign: TextAlign.center, style: rastStyle(size: 12, weight: 450, height: 1.8, color: c.body)),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: PrimaryButton(label: actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
