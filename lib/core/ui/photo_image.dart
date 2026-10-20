import 'dart:io';

import 'package:flutter/material.dart';

/// Renders an asset (`assets/...`) or a picked file path.
class PhotoImage extends StatelessWidget {
  const PhotoImage(this.src, {super.key, this.fit = BoxFit.cover, this.alignment = Alignment.center, this.width, this.height});

  final String src;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (src.startsWith('assets/')) {
      return Image.asset(src, fit: fit, alignment: alignment, width: width, height: height, excludeFromSemantics: true);
    }
    return Image.file(File(src), fit: fit, alignment: alignment, width: width, height: height, excludeFromSemantics: true,
        errorBuilder: (_, _, _) => ColoredBox(color: const Color(0xFFD7C6B6), child: SizedBox(width: width, height: height)));
  }
}
