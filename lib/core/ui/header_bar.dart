import 'package:flutter/material.dart';

import '../theme/rast_theme.dart';
import 'buttons.dart';

/// The one top bar layout every page uses: a 48 px row whose round buttons
/// sit visually on the page gutter, 12 above and 16 below.
class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key, this.leading, this.center, this.trailing});

  /// Usually an [IconCircleButton]; a plain widget is inset by [inset].
  final Widget? leading;
  final Widget? center;
  final Widget? trailing;

  /// Visual inset of a 36 px circle inside its 48 px hit box.
  static const double inset = (IconCircleButton.hitBox - 36) / 2;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(Space.page - inset, Space.m, Space.page - inset, Space.l);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        height: IconCircleButton.hitBox,
        child: Row(
          children: [
            ?leading,
            Expanded(child: center ?? const SizedBox.shrink()),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Pads a non-button header child so it lines up with the button circles.
class HeaderInset extends StatelessWidget {
  const HeaderInset({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: HeaderBar.inset), child: child);
}
