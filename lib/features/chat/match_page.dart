import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../discovery/people_directory.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../profile/profile_notifier.dart';
import '../safety/safety_notifier.dart';
import 'threads_notifier.dart';

/// "It's a match." Dark stage in both appearances.
class MatchPage extends ConsumerWidget {
  const MatchPage({super.key, required this.personId});
  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final person = ref.person(personId);
    final safety = ref.watch(safetyProvider);
    if (person == null || safety.isUnavailable(personId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/chats');
      });
      return Scaffold(backgroundColor: c.darkStage);
    }
    final me = ref.watch(profileProvider).primaryPhoto;
    final accent = c.isDark ? const Color(0xFFFF9E85) : const Color(0xFFFF8168);
    final muted = c.isDark ? const Color(0xFFBDB3C3) : const Color(0xFFBBBBC4);
    return Scaffold(
      backgroundColor: c.darkStage,
      body: SafeArea(
        child: Column(
          children: [
            HeaderBar(
              leading: const HeaderInset(child: RastLogo(color: Colors.white)),
              trailing: IconCircleButton(
                icon: 'close',
                semanticLabel: 'Keep exploring',
                background: Colors.transparent,
                border: c.isDark ? const Color(0xFF58505D) : const Color(0xFF45454B),
                foreground: c.isDark ? const Color(0xFFE4DBE9) : const Color(0xFFDDDDDD),
                onPressed: () => context.go('/discover'),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: (constraints.maxHeight - Space.xxl).clamp(0.0, double.infinity)),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Text('THAT FEELING? MUTUAL.', style: rastStyle(size: 10, weight: 750, letterSpacing: 1.6, color: muted)),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text.rich(
                      TextSpan(text: "It's a\n", children: [TextSpan(text: 'match.', style: TextStyle(color: accent))]),
                      textAlign: TextAlign.center,
                      style: rastStyle(size: 82, weight: 800, height: 0.98, letterSpacing: -4.5, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Portraits(me: me, other: person.photo),
                  const SizedBox(height: 15),
                  Text('You crossed paths. You both said yes.\nNow give that hello a go.', textAlign: TextAlign.center, style: rastStyle(size: 14, weight: 450, height: 1.65, color: muted)),
                  const SizedBox(height: 23),
                  PrimaryButton(
                    label: 'Say hello',
                    trailingIcon: 'chat',
                    onPressed: () {
                      final thread = ref.read(threadsProvider.notifier).ensureThread(personId);
                      context.go('/chats/${thread.id}');
                    },
                  ),
                  const SizedBox(height: 10),
                  TextLinkButton(label: 'Keep exploring', fullWidth: true, color: c.isDark ? const Color(0xFFBDB3C3) : const Color(0xFFB4B4C0), onPressed: () => context.go('/discover')),
                ],
              ),
            ),
          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Portraits extends StatelessWidget {
  const _Portraits({required this.me, required this.other});
  final String me;
  final String other;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 220,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth + 30;
          Widget portrait(String src, double left, double top, double angle) => Positioned(
                left: left - 15,
                top: top,
                child: Transform.rotate(
                  angle: angle * 3.14159 / 180,
                  child: Container(
                    width: w * 0.43,
                    height: 220 * 0.88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: c.isDark ? const Color(0xFFE2D9D3) : Colors.white, width: 3),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: PhotoImage(src, alignment: const Alignment(0, -0.36)),
                  ),
                ),
              );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              portrait(me, w * 0.06, 0, -10),
              portrait(other, w * 0.49, 220 * 0.09, 10),
              Positioned(
                left: constraints.maxWidth / 2 - 22,
                top: 110 - 22,
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: c.isDark ? c.primary : c.accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: c.darkStage, spreadRadius: 5)],
                  ),
                  child: const Center(child: RastIcon('heart', size: 23, color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
