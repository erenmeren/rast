import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';
import 'buttons.dart';

/// Back button, small centred title and optional five step bars.
class SubHeader extends StatelessWidget {
  const SubHeader({super.key, required this.title, this.onBack, this.step = 0});

  final String title;
  final VoidCallback? onBack;
  final int step;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 6, 13, 11),
      child: Row(
        children: [
          IconCircleButton(
            icon: 'back',
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            semanticLabel: 'Back',
            size: 35,
            iconSize: 17,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: rastStyle(size: 13, weight: 700, color: c.isDark ? c.label : const Color(0xFF595964)),
            ),
          ),
          if (step > 0)
            Semantics(
              label: 'Step $step of 5',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var n = 1; n <= 5; n++)
                    Padding(
                      padding: EdgeInsets.only(left: n == 1 ? 0 : 4),
                      child: Container(
                        key: Key('step-bar-$n-${n <= step ? 'done' : 'todo'}'),
                        width: 16,
                        height: 3,
                        decoration: BoxDecoration(
                          color: n <= step ? c.accent : (c.isDark ? const Color(0xFF3B3943) : const Color(0xFFEEEEF1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
