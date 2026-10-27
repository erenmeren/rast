import 'package:flutter/material.dart';

import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';

/// Four numbered slots. Slot 1 is the main photo.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.photos, required this.onPick, required this.onRemove});

  final List<String?> photos;
  final void Function(int slot) onPick;
  final void Function(int slot) onRemove;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 3 / 3.45,
      children: [for (var i = 0; i < 4; i++) _Slot(index: i, src: photos[i], onPick: () => onPick(i), onRemove: () => onRemove(i))],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.index, required this.src, required this.onPick, required this.onRemove});
  final int index;
  final String? src;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filled = src != null;
    return Semantics(
      button: true,
      label: '${filled ? 'Change' : 'Add'} photo ${index + 1}',
      child: Material(
        color: c.raised,
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('photo-slot-$index'),
          onTap: onPick,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (filled) ...[
                PhotoImage(src!, alignment: const Alignment(0, -0.3)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment(0, -0.3), colors: [Color(0x33000000), Color(0x00000000)]),
                  ),
                ),
              ] else
                CustomPaint(painter: _DashedBorder(c.placeholder)),
              if (!filled)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RastIcon('plus', size: 25, color: c.accent),
                      const SizedBox(height: 8),
                      Text('Add photo', style: rastStyle(size: 11, weight: 500, color: c.placeholder)),
                    ],
                  ),
                ),
              Positioned(
                top: 10,
                left: 11,
                child: Text(
                  '0${index + 1}',
                  style: rastStyle(size: 10, weight: 650, color: filled ? Colors.white : c.placeholder),
                ),
              ),
              if (filled)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Semantics(
                    button: true,
                    label: 'Remove photo ${index + 1}',
                    child: InkWell(
                      key: Key('photo-remove-$index'),
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        child: Container(
                          width: 27,
                          height: 27,
                          decoration: BoxDecoration(color: c.isDark ? const Color(0xC416161C) : const Color(0x55202124), shape: BoxShape.circle),
                          child: const Center(child: RastIcon('close', size: 13, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
              if (filled && index == 0)
                Positioned(
                  bottom: 9,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(color: c.isDark ? const Color(0xED262127) : Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Text('MAIN PHOTO', style: rastStyle(size: 8, weight: 800, letterSpacing: 0.5, color: c.accent)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(17)).deflate(0.5);
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
