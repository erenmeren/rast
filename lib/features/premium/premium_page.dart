import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import 'premium_notifier.dart';

/// Subscription preview. Prices are illustrative; nothing is charged.
/// Production: store products, server-verified entitlements.
class PremiumPage extends ConsumerStatefulWidget {
  const PremiumPage({super.key});

  @override
  ConsumerState<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends ConsumerState<PremiumPage> {
  String _plan = 'year';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final premium = ref.watch(premiumProvider);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.38, 0.72],
            colors: c.isDark
                ? const [Color(0xFF352420), Color(0xFF231E20), Color(0xFF18191D)]
                : const [Color(0xFFFFF0E8), Color(0xFFFFF8F5), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              HeaderBar(
                leading: IconCircleButton(
                  icon: 'back',
                  semanticLabel: 'Back',
                  background: c.isDark ? const Color(0xAA3D2D2B) : const Color(0x80FFFFFF),
                  foreground: c.isDark ? const Color(0xFFE5BFB2) : c.text,
                  onPressed: () => context.canPop() ? context.pop() : context.go('/likes'),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const RastLogo(size: 29),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(color: c.isDark ? c.primary : c.accent, borderRadius: BorderRadius.circular(6)),
                            child: Text('PLUS', style: rastStyle(size: 8, weight: 800, letterSpacing: 0.8, color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text('Less guessing.\nMore connecting.', textAlign: TextAlign.center, style: RastText.setupHeadline(c)),
                      const SizedBox(height: Space.m),
                      Text("See who's already into you.", style: RastText.pageSubtitle(c)),
                      const SizedBox(height: 22),
                      const _Art(),
                      const SizedBox(height: 7),
                      _benefit(c, 'heart', 'See all your likes', 'Clear profiles. No blurred previews.'),
                      _benefit(c, 'mark', 'Make a mutual move', 'Like them back and start a conversation.'),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(child: _Plan(name: '1 month', price: '\$14.99', note: '\$14.99 billed monthly', selected: _plan == 'month', onTap: () => setState(() => _plan = 'month'))),
                          const SizedBox(width: 9),
                          Expanded(child: _Plan(name: '12 months', price: '\$7.49', note: '\$89.88 billed annually', save: 'SAVE 50%', selected: _plan == 'year', onTap: () => setState(() => _plan = 'year'))),
                        ],
                      ),
                      const SizedBox(height: 17),
                      PrimaryButton(
                        label: premium ? 'Back to your likes' : 'Get rast Plus',
                        onPressed: () {
                          if (!premium) {
                            ref.read(premiumProvider.notifier).activatePreview();
                            showToast(context, 'Premium preview unlocked. No payment was made.');
                          }
                          context.go('/likes');
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Example prices. Demo upgrade only — no charge.\nIn a live subscription, the selected plan would renew until cancelled.',
                        textAlign: TextAlign.center,
                        style: rastStyle(size: 10, weight: 450, height: 1.6, color: c.isDark ? c.body : const Color(0xFF7B707D)),
                      ),
                      TextLinkButton(label: 'Restore purchases', size: 11, onPressed: () => showToast(context, 'This is a demo. There are no purchases to restore.')),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RastIcon('shield', size: 10, color: c.isDark ? c.body : const Color(0xFF817581)),
                          const SizedBox(width: 5),
                          Text('Your privacy delay always comes first.', style: rastStyle(size: 10, weight: 450, color: c.isDark ? c.body : const Color(0xFF817581))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefit(RastColors c, String icon, String title, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          children: [
            RastIcon(icon, size: 20, color: c.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: rastStyle(size: 14, weight: 750, color: c.isDark ? c.label : const Color(0xFF4C4651))),
                  const SizedBox(height: 4),
                  Text(text, style: rastStyle(size: 12, weight: 450, color: c.isDark ? c.body : const Color(0xFF7B7480))),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Art extends StatelessWidget {
  const _Art();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget mini(String src, double angle, {bool blur = false, bool heart = false, double w = 99, double h = 146}) => Transform.rotate(
          angle: angle * 3.14159 / 180,
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.isDark ? const Color(0xFF4A3834) : Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Color(0x209D5C3C), blurRadius: 15, offset: Offset(0, 5))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (blur)
                  ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6), child: Transform.scale(scale: 1.12, child: PhotoImage(src, alignment: const Alignment(0, -0.4))))
                else
                  PhotoImage(src, alignment: const Alignment(0, -0.4)),
                if (heart)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: c.isDark ? c.primary : c.accent, shape: BoxShape.circle),
                        child: const Center(child: RastIcon('heart', size: 16, color: Colors.white)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
    return SizedBox(
      height: 174,
      width: 245,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(left: 5, top: 13, child: mini(portrait(5), -13, blur: true)),
          Positioned(right: 1, top: 13, child: mini(portrait(2), 13, blur: true)),
          Positioned(top: 0, child: mini(portrait(1), 0, heart: true, w: 112, h: 165)),
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.name, required this.price, required this.note, required this.selected, required this.onTap, this.save});
  final String name;
  final String price;
  final String note;
  final bool selected;
  final VoidCallback onTap;
  final String? save;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final border = selected ? c.accent : (c.isDark ? const Color(0xFF51424B) : const Color(0xFFE4E4EB));
    final bg = selected ? (c.isDark ? const Color(0xFF382621) : const Color(0xFFFFF5EF)) : (c.isDark ? const Color(0xFF231F25) : Colors.white);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(11, 15, 11, 13),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 1.5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: rastStyle(size: 12, weight: 750, color: selected ? (c.isDark ? const Color(0xFFFFAD98) : const Color(0xFFDC6B50)) : (c.isDark ? c.body : const Color(0xFF6E6570)))),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(text: price, children: [TextSpan(text: ' / mo', style: rastStyle(size: 11, weight: 500, color: c.isDark ? c.body : const Color(0xFF7D7380)))]),
                    style: rastStyle(size: 23, weight: 800, letterSpacing: -0.7, color: c.isDark ? c.label : const Color(0xFF3B3B45)),
                  ),
                  const SizedBox(height: 7),
                  Text(note, style: rastStyle(size: 10, weight: 450, color: c.isDark ? c.body : const Color(0xFF756C78))),
                ],
              ),
            ),
            if (save != null)
              Positioned(
                right: 8,
                top: -9,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(color: c.isDark ? c.primary : const Color(0xFFCA4331), borderRadius: BorderRadius.circular(12)),
                  child: Text(save!, style: rastStyle(size: 9, weight: 800, letterSpacing: 0.5, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
