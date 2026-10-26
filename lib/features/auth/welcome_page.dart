import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../profile/sheets/policy_sheets.dart';
import 'session_notifier.dart';

/// Dark stage in both appearances.
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final accent = c.isDark ? const Color(0xFFFF9E85) : const Color(0xFFFF8269);
    final muted = c.isDark ? const Color(0xFFBDB3C3) : const Color(0xFFBBBBC4);
    void begin() {
      ref.read(sessionProvider.notifier).startSignup();
      context.go('/auth/phone');
    }

    return Scaffold(
      backgroundColor: c.darkStage,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(25, 25, 25, 23),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: (constraints.maxHeight - 48).clamp(0.0, double.infinity)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const RastLogo(size: 35, color: Colors.white),
                      const SizedBox(width: 12),
                      Flexible(child: Text('A LITTLE CLOSER.', overflow: TextOverflow.ellipsis, style: rastStyle(size: 9, weight: 750, letterSpacing: 1, color: c.isDark ? const Color(0xFFAAA0B0) : const Color(0xFF6F707A)))),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const _WelcomeVisual(),
                  const SizedBox(height: 26),
                  Semantics(
                    header: true,
                    child: Text.rich(
                      TextSpan(
                        text: 'Good things\nhappen ',
                        children: [TextSpan(text: 'nearby.', style: TextStyle(color: accent))],
                      ),
                      style: rastStyle(size: 51, weight: 800, height: 1.05, letterSpacing: -2.7, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Meet the people life brings your way.\nMake the next move yours.',
                    style: rastStyle(size: 14, weight: 450, height: 1.65, color: muted),
                  ),
                  const SizedBox(height: 27),
                  PrimaryButton(label: "Let's get you out there", onPressed: begin),
                  const SizedBox(height: 13),
                  Center(
                    child: TextButton(
                      onPressed: begin,
                      style: TextButton.styleFrom(minimumSize: const Size(0, 36)),
                      child: Text.rich(
                        TextSpan(
                          text: 'Already here? ',
                          children: [
                            TextSpan(
                              text: 'Log in',
                              style: TextStyle(color: c.isDark ? const Color(0xFFDFD6E4) : const Color(0xFFBBBCC5), decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                        style: rastStyle(size: 12, weight: 600, color: c.isDark ? const Color(0xFFAAA0B0) : const Color(0xFFAAAAB5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        text: '18+ only. By continuing, you agree to our\n',
                        children: [
                          WidgetSpan(child: _Link('Terms', () => showTermsSheet(context))),
                          const TextSpan(text: ' and '),
                          WidgetSpan(child: _Link('Privacy information', () => showPrivacySheet(context))),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: rastStyle(size: 10, weight: 450, height: 1.8, color: c.isDark ? const Color(0xFFAAA0B0) : const Color(0xFF9D9DA8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.isDark ? const Color(0xFFDFD6E4) : const Color(0xFFC7C7D0);
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: rastStyle(size: 10, weight: 450, height: 1.8, color: color).copyWith(decoration: TextDecoration.underline, decorationColor: color)),
    );
  }
}

class _WelcomeVisual extends StatelessWidget {
  const _WelcomeVisual();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 235,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth + 18;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -9 + w * 0.01,
                top: 0,
                child: _Portrait(portrait(1), width: w * 0.48, height: 235 * 0.9, angle: -9),
              ),
              Positioned(
                left: -9 + w * 0.49,
                top: 23,
                child: _Portrait(portrait(4), width: w * 0.48, height: 235 * 0.88, angle: 9),
              ),
              Positioned(
                left: constraints.maxWidth / 2 - 22,
                top: 235 * 0.47,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.isDark ? c.primary : c.accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: c.darkStage, spreadRadius: 5)],
                  ),
                  child: const Center(child: RastIcon('mark', size: 24, color: Colors.white)),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 7,
                child: Transform.rotate(
                  angle: -6 * 3.14159 / 180,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: c.isDark ? const Color(0xFF29252C) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.isDark ? const Color(0xFF66525D) : const Color(0xFFEEEEEE)),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('You crossed paths', style: rastStyle(size: 11, weight: 750, color: c.isDark ? const Color(0xFFE8DBE7) : const Color(0xFF5E5E69))),
                        const SizedBox(width: 7),
                        RastIcon('spark', size: 12, color: c.accent),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait(this.src, {required this.width, required this.height, required this.angle});
  final String src;
  final double width;
  final double height;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Transform.rotate(
      angle: angle * 3.14159 / 180,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.isDark ? const Color(0xFFE2D9D3) : Colors.white, width: 3),
        ),
        clipBehavior: Clip.antiAlias,
        child: PhotoImage(src, alignment: const Alignment(0, -0.3)),
      ),
    );
  }
}
