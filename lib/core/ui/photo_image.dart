import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories.dart';

const Color _placeholder = Color(0xFFD7C6B6);

/// Renders an asset (`assets/...`), a picked file path, or a remote source
/// (`sb:` original, `preview:` Likes You token) resolved by the photo
/// repository once per source. Remote sources need a ProviderScope.
class PhotoImage extends StatelessWidget {
  const PhotoImage(this.src, {super.key, this.fit = BoxFit.cover, this.alignment = Alignment.center, this.width, this.height});

  final String src;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  static bool isRemote(String src) => src.startsWith('sb:') || src.startsWith('preview:');

  @override
  Widget build(BuildContext context) {
    if (src.startsWith('assets/')) {
      return Image.asset(src, fit: fit, alignment: alignment, width: width, height: height, excludeFromSemantics: true);
    }
    if (isRemote(src)) {
      return _RemotePhoto(src: src, fit: fit, alignment: alignment, width: width, height: height);
    }
    return Image.file(File(src), fit: fit, alignment: alignment, width: width, height: height, excludeFromSemantics: true,
        errorBuilder: (_, _, _) => _Blank(width: width, height: height));
  }
}

class _Blank extends StatelessWidget {
  const _Blank({this.width, this.height});
  final double? width;
  final double? height;
  @override
  Widget build(BuildContext context) => ColoredBox(color: _placeholder, child: SizedBox(width: width, height: height));
}

class _RemotePhoto extends ConsumerStatefulWidget {
  const _RemotePhoto({required this.src, required this.fit, required this.alignment, this.width, this.height});
  final String src;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  @override
  ConsumerState<_RemotePhoto> createState() => _RemotePhotoState();
}

class _RemotePhotoState extends ConsumerState<_RemotePhoto> {
  late Future<ImageRequest?> _request;

  @override
  void initState() {
    super.initState();
    _request = ref.read(photoRepositoryProvider).resolve(widget.src);
  }

  @override
  void didUpdateWidget(_RemotePhoto old) {
    super.didUpdateWidget(old);
    if (old.src != widget.src) _request = ref.read(photoRepositoryProvider).resolve(widget.src);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _request,
        builder: (context, snap) {
          final req = snap.data;
          if (req == null) return _Blank(width: widget.width, height: widget.height);
          return Image.network(req.uri.toString(), headers: req.headers,
              fit: widget.fit, alignment: widget.alignment, width: widget.width, height: widget.height, excludeFromSemantics: true,
              errorBuilder: (_, _, _) => _Blank(width: widget.width, height: widget.height));
        },
      );
}
