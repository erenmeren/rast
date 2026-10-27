import 'package:flutter/material.dart';

import '../rules/rules.dart';
import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';

/// One track, two handles, 18 to 99+. Keeps min <= max.
class AgeRangeSlider extends StatelessWidget {
  const AgeRangeSlider({super.key, required this.minAge, required this.maxAge, required this.onChanged});

  final int minAge;
  final int maxAge;
  final void Function(int min, int max) onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lo = minAge.clamp(18, 99);
    final hi = maxAge.clamp(lo, 99);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Age range', style: rastStyle(size: 14, weight: 700, color: c.label)),
            Text(
              '$lo–${ageLabel(hi)}',
              key: const Key('age-range-label'),
              style: rastStyle(size: 17, weight: 750, letterSpacing: -0.6, color: c.accent),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: c.accent,
            inactiveTrackColor: c.outline,
            rangeThumbShape: _RingThumb(c),
            overlayColor: c.accent.withValues(alpha: 0.12),
            rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: RangeSlider(
            min: 18,
            max: 99,
            divisions: 81,
            values: RangeValues(lo.toDouble(), hi.toDouble()),
            labels: RangeLabels('$lo', ageLabel(hi)),
            semanticFormatterCallback: (v) => ageLabel(v.round()),
            onChanged: (v) {
              var min = v.start.round();
              var max = v.end.round();
              if (min > max) {
                min = max;
              }
              onChanged(min, max);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('18', style: rastStyle(size: 12, weight: 450, color: c.body)),
            Text('99+', style: rastStyle(size: 12, weight: 450, color: c.body)),
          ],
        ),
      ],
    );
  }
}

class _RingThumb extends RangeSliderThumbShape {
  const _RingThumb(this.c);
  final RastColors c;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(25, 25);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool? isOnTop,
    TextDirection? textDirection,
    required SliderThemeData sliderTheme,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center + const Offset(0, 2), 12.5, Paint()..color = const Color(0x26DC4C34)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(center, 12.5, Paint()..color = c.isDark ? c.raised : Colors.white);
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..color = c.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}
