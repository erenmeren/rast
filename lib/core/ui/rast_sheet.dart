import 'package:flutter/material.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';
import 'buttons.dart';

/// Modal bottom sheet with handle, title and close button. Top radius 27,
/// side padding on the page gutter, scrollable and keyboard-aware.
Future<T?> showRastSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  final c = context.colors;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.sheet,
    barrierColor: c.isDark ? const Color(0xB807080C) : const Color(0x5523232F),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(27)),
      side: c.isDark ? const BorderSide(color: Color(0xFF3A3740)) : BorderSide.none,
    ),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.93),
    builder: (sheetContext) => _SheetBody(title: title, child: Builder(builder: builder)),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: rastButtonDuration,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.m, Space.page, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 33,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: c.isDark ? const Color(0xFF605A66) : const Color(0xFFE2E2E9),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: RastText.sheetTitle(c)),
                  ),
                ),
                const SizedBox(width: 10),
                IconCircleButton(
                  icon: 'close',
                  size: 28,
                  iconSize: 14,
                  onPressed: () => Navigator.of(context).pop(),
                  semanticLabel: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Section heading + content block used inside policy sheets.
class PolicySection extends StatelessWidget {
  const PolicySection({super.key, this.heading, required this.text});
  final String? heading;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heading != null) ...[
            Text(heading!, style: rastStyle(size: 14, weight: 750, color: c.isDark ? c.label : const Color(0xFF4E4E5B))),
            const SizedBox(height: 4),
          ],
          Text(text, style: rastStyle(size: 13, weight: 450, height: 1.9, color: c.isDark ? c.body : const Color(0xFF70707C))),
        ],
      ),
    );
  }
}
