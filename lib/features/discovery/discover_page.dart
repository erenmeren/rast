import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../premium/premium_notifier.dart';
import '../profile/profile_notifier.dart';
import '../profile/settings_notifier.dart';
import '../profile/sheets/filters_sheet.dart';
import '../profile/sheets/location_sheet.dart';
import '../safety/sheets/person_menu_sheet.dart';
import 'deck_notifier.dart';
import 'eligibility.dart';
import 'like_action.dart';
import 'profile_card.dart';

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final _cardKey = GlobalKey<ProfileCardState>();

  void _swipe(SwipeDirection direction) {
    final person = ref.read(currentPersonProvider);
    if (person == null) return;
    if (direction == SwipeDirection.like) {
      likePerson(context, ref, person, returnTo: '/discover');
    } else {
      passPerson(context, ref, person);
    }
  }

  Future<void> _rewind() async {
    final id = await ref.read(deckProvider.notifier).rewind();
    if (!mounted) return;
    showToast(context, id == null ? 'No passes to rewind yet.' : 'Your last pass has been undone.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final person = ref.watch(currentPersonProvider);
    final deck = ref.watch(deckProvider);
    final settings = ref.watch(settingsProvider);
    final profile = ref.watch(profileProvider);
    final active = ref.watch(discoveryActiveProvider);
    final premium = ref.watch(premiumProvider);
    final hasHistory = deck.history.isNotEmpty;

    Widget content;
    if (person != null) {
      content = Column(
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 240),
              child: ProfileCard(
                key: _cardKey,
                person: person,
                photoIndex: deck.photoIndex,
                onPrev: ref.read(deckProvider.notifier).prevPhoto,
                onNext: ref.read(deckProvider.notifier).nextPhoto,
                onMenu: () => showPersonMenu(context, ref, person.id, returnTo: '/discover'),
                onDetail: () => context.push('/discover/people/${person.id}'),
                onSwipe: _swipe,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 17, 0, 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundAction(key: const Key('action-rewind'), icon: 'rewind', size: 37, iconSize: 16, semanticLabel: 'Rewind last pass', onTap: hasHistory ? _rewind : null),
                const SizedBox(width: 27),
                _RoundAction(icon: 'close', size: 58, iconSize: 24, semanticLabel: 'Pass profile', onTap: () => _cardKey.currentState?.flyOut(SwipeDirection.pass) ?? _swipe(SwipeDirection.pass)),
                const SizedBox(width: 27),
                _LikeAction(onTap: () => _cardKey.currentState?.flyOut(SwipeDirection.like) ?? _swipe(SwipeDirection.like)),
                const SizedBox(width: 27),
                _RoundAction(icon: 'info', size: 37, iconSize: 14, semanticLabel: 'How encounters work', onTap: () => context.go('/profile/how-it-works')),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RastIcon('lock', size: 10, color: c.menuDetail),
              const SizedBox(width: 5),
              Text('Your exact location stays private.', style: rastStyle(size: 10, weight: 450, color: c.menuDetail)),
            ],
          ),
          const SizedBox(height: 2),
        ],
      );
    } else {
      final needsPhotos = !profile.photosComplete;
      final paused = !settings.visible;
      final needsLocation = !settings.locationEnabled;
      content = EmptyState(
        icon: paused ? 'pause' : needsLocation ? 'locate' : 'mark',
        title: needsPhotos
            ? 'Your photos come first.'
            : paused
                ? 'Taking a little breather.'
                : needsLocation
                    ? 'Let your paths cross.'
                    : "You're all caught up.",
        text: needsPhotos
            ? 'Add all four photos to discover new connections.'
            : paused
                ? 'Your visibility is paused. Pick things up when you are ready.'
                : needsLocation
                    ? 'Enable location to discover people whose paths cross yours.'
                    : 'New encounters appear once their privacy delay has passed.',
        actionLabel: needsPhotos
            ? 'Complete your photos'
            : paused
                ? 'Resume encounters'
                : needsLocation
                    ? 'Enable location'
                    : 'Adjust preferences',
        onAction: () {
          if (needsPhotos) {
            context.go('/profile/photos');
          } else if (paused) {
            ref.read(settingsProvider.notifier).setVisible(true);
          } else if (needsLocation) {
            showLocationSheet(context, ref);
          } else {
            showFiltersSheet(context, ref);
          }
        },
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(action: 'filters', premium: premium, onAction: () => showFiltersSheet(context, ref)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.m),
                child: Column(
                  children: [
                    PageTitle(
                      title: 'Discover',
                      subtitle: 'Real-life crossings. A fresh mix.',
                      trailing: Semantics(
                        button: true,
                        label: active ? 'Encounters active' : 'Encounters paused',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => context.go('/profile/location'),
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: active ? c.statusActiveBg : c.raised,
                                shape: BoxShape.circle,
                              ),
                              child: Center(child: RastIcon(active ? 'locate' : 'pause', size: 14, color: active ? c.statusActiveFg : c.placeholder)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: content),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({super.key, required this.icon, required this.size, required this.iconSize, required this.semanticLabel, required this.onTap});
  final String icon;
  final double size;
  final double iconSize;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: c.isDark ? c.raised : Colors.white,
          shape: CircleBorder(side: BorderSide(color: c.outline)),
          elevation: size > 40 ? 1 : 0,
          shadowColor: const Color(0x0A181823),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size < 48 ? 48 : size,
              height: size < 48 ? 48 : size,
              child: Center(child: RastIcon(icon, size: iconSize, color: size > 40 ? c.label : c.placeholder)),
            ),
          ),
        ),
      ),
    );
  }
}

class _LikeAction extends StatelessWidget {
  const _LikeAction({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Like profile',
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: c.isDark ? const [Color(0xFFFA785E), Color(0xFFDA4438)] : const [Color(0xFFFF8364), Color(0xFFF5564C)],
          ),
          boxShadow: [BoxShadow(color: c.accent.withValues(alpha: c.isDark ? 0.2 : 0.25), blurRadius: 18, offset: const Offset(0, 7))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const Center(child: RastIcon('heart', size: 27, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
