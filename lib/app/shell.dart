import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/rast_colors.dart';
import '../core/theme/rast_theme.dart';
import '../core/ui/rast_icon.dart';
import '../features/discovery/eligibility.dart';

const List<({String icon, String label})> navItems = [
  (icon: 'mark', label: 'Discover'),
  (icon: 'heart', label: 'Likes You'),
  (icon: 'chat', label: 'Chats'),
  (icon: 'user', label: 'Profile'),
];

/// Persistent four-tab shell. Discover · Likes You · Chats · Profile.
class RastShell extends ConsumerWidget {
  const RastShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likes = ref.watch(incomingLikesProvider).length;
    final unread = ref.watch(hasUnreadProvider);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: RastBottomNav(
        currentIndex: navigationShell.currentIndex,
        likesCount: likes,
        hasUnread: unread,
        onTap: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
      ),
    );
  }
}

class RastBottomNav extends StatelessWidget {
  const RastBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.likesCount = 0,
    this.hasUnread = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int likesCount;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 68 + bottom,
      padding: EdgeInsets.fromLTRB(5, 1, 5, bottom > 11 ? bottom : 11),
      decoration: BoxDecoration(
        color: c.canvas,
        border: Border(top: BorderSide(color: c.isDark ? c.outline : const Color(0xFFF0F0F3))),
      ),
      child: Row(
        children: [
          for (var i = 0; i < navItems.length; i++)
            Expanded(
              child: _NavButton(
                icon: navItems[i].icon,
                label: navItems[i].label,
                active: i == currentIndex,
                badge: i == 1 && likesCount > 0 ? '$likesCount' : null,
                dot: i == 2 && hasUnread,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.active, required this.onTap, this.badge, this.dot = false});
  final String icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String? badge;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.navActive : c.navInactive;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 27,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    RastIcon(icon, size: 23, color: color),
                    if (badge != null)
                      Positioned(
                        right: 0,
                        top: -3,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.isDark ? c.primary : c.accent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.canvas, width: 2),
                          ),
                          child: Center(child: Text(badge!, style: rastStyle(size: 8, weight: 800, height: 1, color: Colors.white))),
                        ),
                      ),
                    if (dot)
                      Positioned(
                        right: 6,
                        top: 0,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: c.canvas)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: rastStyle(size: 10, weight: 700, letterSpacing: -0.1, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
