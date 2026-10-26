import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

const Color _placeholder = Color(0xFFD7C6B6);

/// Renders an asset (`assets/...`), a picked file path, or a remote source
/// (`sb:` original, `preview:` Likes You token) resolved by the photo
/// repository. Remote sources need a ProviderScope; the rest do not.
class PhotoImage extends StatelessWidget {
  const PhotoImage(this.src, {super.key, this.fit = BoxFit.cover, this.alignment = Alignment.center, this.width, this.height});

  final String src;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  static bool isRemote(String src) => src.startsWith('sb:') || src.startsWith('preview:');

  Widget _blank() => ColoredBox(color: _placeholder, child: SizedBox(width: width, height: height));

  @override
  Widget build(BuildContext context) {
    if (src.startsWith('assets/')) {
      return Image.asset(src, fit: fit, alignment: alignment, width: width, height: height, excludeFromSemantics: true);
    }
    if (isRemote(src)) {
      return Consumer(
        builder: (context, ref, _) => FutureBuilder(
          future: ref.read(photoRepositoryProvider).resolve(src),
          builder: (context, snap) {
            final req = snap.data;
            if (req == null) return _blank();
            return Image.network(req.uri.toString(), headers: req.headers,
                fit: fit, alignment: alignment, width: width, height: height, excludeFromSemantics: true,
                errorBuilder: (_, _, _) => _blank());
          },
        ),
      );
    }
    return Image.file(File(src), fit: fit, alignment: alignment, width: width, height: height, excludeFromSemantics: true,
        errorBuilder: (_, _, _) => _blank());
  }
}
