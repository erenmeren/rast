import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One of the 36 handoff icons under `assets/icons/`, tinted with [color]
/// (defaults to the ambient icon colour). The `mark` icon is 26×24.
class RastIcon extends StatelessWidget {
  const RastIcon(this.name, {super.key, this.size = 22, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color ?? Colors.black;
    final width = name == 'mark' ? size * 26 / 24 : size;
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: width,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}
