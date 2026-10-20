import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import 'photo_image.dart';

/// Round portrait. [highlighted] adds the coral ring used for new matches.
class Avatar extends StatelessWidget {
  const Avatar(this.src, {super.key, this.size = 54, this.highlighted = false});

  final String src;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final image = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: PhotoImage(src, alignment: const Alignment(0, -0.36)),
      ),
    );
    if (!highlighted) return image;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.accent, width: 2)),
      child: image,
    );
  }
}
