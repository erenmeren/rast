import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/rast_colors.dart';
import '../theme/rast_theme.dart';
import 'rast_icon.dart';

OverlayEntry? _current;

/// Dark pill above the bottom navigation for 3.8 s. Also announced.
void showToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _current?.remove();
  _current = null;
  final c = context.colors;
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: 18,
      right: 18,
      bottom: 88 + MediaQuery.paddingOf(context).bottom,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
            decoration: BoxDecoration(
              color: c.toastBg,
              borderRadius: BorderRadius.circular(14),
              border: c.isDark ? Border.all(color: const Color(0xFF635662)) : null,
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: RastIcon('check', size: 15, color: c.isDark ? c.accent : const Color(0xFFFF9176)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(message, style: rastStyle(size: 12, weight: 500, height: 1.7, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  _current = entry;
  overlay.insert(entry);
  SemanticsService.sendAnnouncement(View.of(context), message, TextDirection.ltr);
  Future<void>.delayed(const Duration(milliseconds: 3800), () {
    if (_current == entry) {
      entry.remove();
      _current = null;
    }
  });
}
