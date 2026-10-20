import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/rules/rules.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../premium/premium_notifier.dart';
import '../safety/sheets/person_menu_sheet.dart';
import 'eligibility.dart';
import 'like_action.dart';

/// Full-bleed album with like / pass / report. [origin] is `discover` or
/// `likes` and decides where actions return to and whether Premium is needed.
class PersonDetailPage extends ConsumerStatefulWidget {
  const PersonDetailPage({super.key, required this.personId, required this.origin});
  final String personId;
  final String origin;

  @override
  ConsumerState<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends ConsumerState<PersonDetailPage> {
  int _photo = 0;

  String get _returnTo => widget.origin == 'likes' ? '/likes' : '/discover';
  bool get _fromLikes => widget.origin == 'likes';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final premium = ref.watch(premiumProvider);
    final people = ref.watch(eligiblePeopleProvider);
    Person? person;
    for (final p in people) {
      if (p.id == widget.personId) person = p;
    }
    if (person == null || (_fromLikes && !premium)) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SubHeader(title: 'Profile unavailable'),
              Expanded(
                child: EmptyState(
                  icon: 'lock',
                  title: 'This profile is unavailable.',
                  text: 'Your current preferences and visibility settings always apply.',
                  actionLabel: 'Back to ${_fromLikes ? 'Likes You' : 'Discover'}',
                  onAction: () => context.go(_returnTo),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final p = person;
    final frame = albumOf(p)[_photo % 4];
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 360,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Transform.scale(scale: frame.zoom, child: PhotoImage(frame.src, alignment: frame.alignment)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center, colors: [Color(0x9E1C1414), Color(0x00000000)]),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 9, 11, 0),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: IconCircleButton(
                        icon: 'back',
                        semanticLabel: 'Back',
                        background: c.isDark ? const Color(0xDF222128) : const Color(0xDDFFFFFF),
                        foreground: c.isDark ? Colors.white : c.text,
                        onPressed: () => context.canPop() ? context.pop() : context.go(_returnTo),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 23,
                  bottom: 24,
                  child: Text(ageLabel(p.age), style: rastStyle(size: 47, weight: 800, height: 1, letterSpacing: -1.4, color: Colors.white)),
                ),
                Positioned(
                  right: 20,
                  bottom: 24,
                  child: Row(
                    children: [
                      _PhotoButton(icon: 'back', label: 'Previous photo', onTap: () => setState(() => _photo = (_photo + 3) % 4)),
                      const SizedBox(width: 8),
                      Text('${_photo % 4 + 1} / 4', style: rastStyle(size: 10, weight: 650, color: Colors.white)),
                      const SizedBox(width: 8),
                      _PhotoButton(icon: 'arrow', label: 'Next photo', onTap: () => setState(() => _photo = (_photo + 1) % 4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 21, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Pill(label: 'You crossed paths', accent: true, icon: 'mark'),
                  const SizedBox(height: 14),
                  Text('A real-life crossing.\nA new possibility.', style: rastStyle(size: 27, weight: 800, height: 1.2, letterSpacing: -1, color: c.text)),
                  const SizedBox(height: 11),
                  Text('You are both open to a connection.\nGive your next hello a chance.', style: rastStyle(size: 13, weight: 450, height: 1.65, color: c.body)),
                  const SizedBox(height: 21),
                  Container(
                    padding: const EdgeInsets.only(top: 17),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.outline))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: const EdgeInsets.only(top: 2), child: RastIcon('lock', size: 15, color: c.menuDetail)),
                        const SizedBox(width: 9),
                        Expanded(child: Text('Exact locations and crossing times are never shown.', style: rastStyle(size: 12, weight: 450, height: 1.65, color: c.menuDetail))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: p.likesYou && premium ? 'Like back' : 'Like profile',
                    leadingIcon: 'heart',
                    trailingIcon: null,
                    onPressed: () => likePerson(context, ref, p, returnTo: _returnTo, fromLikes: _fromLikes),
                  ),
                  const SizedBox(height: 4),
                  TextLinkButton(label: 'Pass for now', fullWidth: true, onPressed: () => passPerson(context, ref, p, returnTo: _returnTo)),
                  TextLinkButton(label: 'Report or block profile', fullWidth: true, onPressed: () => showPersonMenu(context, ref, p.id, returnTo: _returnTo)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(color: const Color(0x2BFFFFFF), shape: BoxShape.circle, border: Border.all(color: const Color(0x55FFFFFF))),
              child: Center(child: RastIcon(icon, size: 13, color: Colors.white)),
            ),
          ),
        ),
      );
}
