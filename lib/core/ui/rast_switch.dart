import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';

/// 41×25 pill switch with a 19px knob.
class RastSwitch extends StatelessWidget {
  const RastSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = c.isDark ? c.primary : c.accent;
    final off = c.outline;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: rastButtonDuration,
              curve: rastEase,
              width: 41,
              height: 25,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: value ? on : off, borderRadius: BorderRadius.circular(30)),
              child: AnimatedAlign(
                duration: rastButtonDuration,
                curve: rastEase,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: value || !c.isDark ? Colors.white : const Color(0xFFDDD7DE),
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 1))],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Title / description / switch" row.
class ToggleRow extends StatelessWidget {
  const ToggleRow({super.key, required this.title, required this.text, required this.value, required this.onChanged});

  final String title;
  final String text;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: rastStyle(size: 14, weight: 750, color: c.label)),
              const SizedBox(height: 6),
              Text(text, style: rastStyle(size: 12, weight: 450, height: 1.6, color: c.body)),
            ],
          ),
        ),
        const SizedBox(width: 20),
        RastSwitch(value: value, onChanged: onChanged, semanticLabel: title),
      ],
    );
  }
}
