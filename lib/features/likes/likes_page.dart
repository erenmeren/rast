import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../discovery/eligibility.dart';
import '../premium/premium_notifier.dart';
import '../profile/sheets/filters_sheet.dart';

/// Eligible incoming likes. Free members see a blurred preview; Premium
/// reveals the same eligible people. The blur here is cosmetic: in
/// production the server only ever sends a protected derivative to a free
/// client, never the original.
class LikesPage extends ConsumerWidget {
  const LikesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final people = ref.watch(incomingLikesProvider);
    final unlocked = ref.watch(premiumProvider);
    final copy = unlocked
        ? 'They made the first move. Your turn.'
        : people.length == 1
            ? "Someone's interested in you."
            : people.isNotEmpty
                ? '${people.length} people already like you.'
                : 'Your next connection starts with a like.';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(action: 'filters', premium: unlocked, onAction: () => showFiltersSheet(context, ref)),
              Row(
                children: [
                  Semantics(header: true, child: Text('Likes You', style: RastText.sectionTitle(c))),
                  if (people.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(color: c.accentContainer, shape: BoxShape.circle),
                      child: Center(child: Text('${people.length}', style: rastStyle(size: 12, weight: 800, color: c.accent))),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 9),
              Text(copy, style: rastStyle(size: 13, weight: 450, height: 1.7, color: c.body)),
              Expanded(
                child: people.isEmpty
                    ? EmptyState(
                        icon: 'heart',
                        title: 'A little spark is out there.',
                        text: 'When someone likes you, they will appear here after your privacy delay.',
                        actionLabel: 'Keep exploring',
                        onAction: () => context.go('/discover'),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 23),
                            if (unlocked) _UnlockedGrid(people: people) else _LockedStack(people: people),
                            if (unlocked)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text('Tap a profile to like them back or pass.', textAlign: TextAlign.center, style: rastStyle(size: 11, weight: 450, height: 1.7, color: c.isDark ? const Color(0xFFACA4B3) : const Color(0xFF797986))),
                              )
                            else
                              _Upsell(onTap: () => context.push('/likes/plus')),
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
}

class _LockedStack extends StatelessWidget {
  const _LockedStack({required this.people});
  final List<Person> people;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = people.take(3).toList();
    return SizedBox(
      height: 273,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final cardW = w * 0.54;
          final positions = shown.length == 1
              ? [(0.23, 14.0, 0.0)]
              : [(0.02, 14.0, -10.0), (0.44, 14.0, 10.0), (0.23, 5.0, 0.0)];
          return Stack(
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: w * positions[i].$1,
                  top: positions[i].$2,
                  child: Transform.rotate(
                    angle: positions[i].$3 * 3.14159 / 180,
                    child: Semantics(
                      button: true,
                      label: 'Unlock an incoming like',
                      child: GestureDetector(
                        key: Key('locked-like-$i'),
                        onTap: () => context.push('/likes/plus'),
                        child: Container(
                          width: cardW,
                          height: 247,
                          decoration: BoxDecoration(
                            color: c.isDark ? const Color(0xFF39333B) : const Color(0xFFECE8E6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.isDark ? const Color(0xFF343038) : Colors.white, width: 4),
                            boxShadow: const [BoxShadow(color: Color(0x1226222B), blurRadius: 24, offset: Offset(0, 8))],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ImageFiltered(
                                imageFilter: ImageFilter.blur(sigmaX: 17, sigmaY: 17),
                                child: Transform.scale(scale: 1.15, child: PhotoImage(shown[i].photo, alignment: const Alignment(0, -0.34))),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment(0, -0.3), colors: [Color(0x8827232B), Color(0x00000000)])),
                              ),
                              Center(
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(color: const Color(0x20FFFFFF), shape: BoxShape.circle, border: Border.all(color: const Color(0x70FFFFFF))),
                                  child: const Center(child: RastIcon('heart', size: 24, color: Colors.white)),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 18,
                                child: Text('Likes you', textAlign: TextAlign.center, style: rastStyle(size: 12, weight: 700, color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
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

class _UnlockedGrid extends StatelessWidget {
  const _UnlockedGrid({required this.people});
  final List<Person> people;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GridView.count(
      crossAxisCount: people.length == 1 ? 1 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: people.length == 1 ? 3 / 3 : 3 / 4,
      children: [
        for (final p in people)
          Semantics(
            button: true,
            label: 'View someone who likes you, age ${p.age}',
            child: GestureDetector(
              key: Key('like-${p.id}'),
              onTap: () => context.push('/likes/people/${p.id}'),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.isDark ? const Color(0xFF322D36) : Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: c.isDark ? const Color(0xFF554650) : const Color(0xFFEFEFEF), spreadRadius: 1)],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PhotoImage(p.photo, alignment: const Alignment(0, -0.34)),
                    const DecoratedBox(
                      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment(0, -0.3), colors: [Color(0x8827232B), Color(0x00000000)])),
                    ),
                    Positioned(left: 15, bottom: 17, child: Text('${p.age}', style: rastStyle(size: 28, weight: 750, letterSpacing: -0.5, color: Colors.white))),
                    Positioned(
                      right: 12,
                      bottom: 15,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: c.isDark ? c.primary : c.accent, shape: BoxShape.circle),
                        child: const Center(child: RastIcon('heart', size: 16, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Upsell extends StatelessWidget {
  const _Upsell({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RastIcon('spark', size: 12, color: c.accent),
            const SizedBox(width: 5),
            Text('rast PLUS', style: rastStyle(size: 11, weight: 800, letterSpacing: -0.2, color: c.accent)),
          ],
        ),
        const SizedBox(height: 9),
        Text('Curiosity looks\ngood on you.', textAlign: TextAlign.center, style: rastStyle(size: 27, weight: 800, height: 1.17, letterSpacing: -0.9, color: c.text)),
        const SizedBox(height: 9),
        Text("See who's already interested.\nFind your next connection faster.", textAlign: TextAlign.center, style: rastStyle(size: 13, weight: 450, height: 1.8, color: c.isDark ? c.body : const Color(0xFF777784))),
        const SizedBox(height: 17),
        PrimaryButton(label: 'See who likes you', onPressed: onTap),
        const SizedBox(height: 12),
        Text('You can still match for free in Discover.', textAlign: TextAlign.center, style: rastStyle(size: 11, weight: 450, height: 1.7, color: c.isDark ? const Color(0xFFACA4B3) : const Color(0xFF797986))),
      ],
    );
  }
}
