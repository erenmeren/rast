import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../auth/session_notifier.dart';
import '../premium/premium_notifier.dart';
import '../profile/settings_notifier.dart';
import '../profile/sheets/policy_sheets.dart';
import 'safety_notifier.dart';
import 'sheets/lists_sheets.dart';

class SafetyPage extends ConsumerWidget {
  const SafetyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final safety = ref.watch(safetyProvider);
    final premium = ref.watch(premiumProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SubHeader(title: 'Safety & account', onBack: () => context.canPop() ? context.pop() : context.go('/profile')),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: Space.xl),
                      padding: const EdgeInsets.all(Space.l),
                      decoration: BoxDecoration(color: c.accentContainer, borderRadius: BorderRadius.circular(Radii.card)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RastIcon('shield', size: 22, color: c.accent),
                          const SizedBox(height: 12),
                          Text('Your boundaries matter.', style: rastStyle(size: 22, weight: 800, letterSpacing: -0.7, color: c.onPlusStrong)),
                          const SizedBox(height: 9),
                          Text("Remove a connection for good, block a profile, or report something that doesn't feel right.", style: rastStyle(size: 12, weight: 450, height: 1.75, color: c.onPlusSoft)),
                        ],
                      ),
                    ),
                    MenuRow(label: 'Removed connections', detail: '${safety.disconnected.length} removed · No future matching', icon: 'close', onTap: () => showRemovedConnectionsSheet(context, ref)),
                    MenuRow(label: 'Blocked profiles', detail: '${safety.blocked.length} people', icon: 'block', onTap: () => showBlockedProfilesSheet(context, ref)),
                    MenuRow(label: 'Privacy information', detail: 'Your location and your data', icon: 'lock', onTap: () => showPrivacySheet(context)),
                    MenuRow(label: 'Terms', detail: 'For adults 18 and over', icon: 'info', onTap: () => showTermsSheet(context)),
                    const SizedBox(height: 20),
                    MenuRow(
                      label: 'Pause visibility',
                      detail: 'Keep your existing conversations',
                      icon: 'pause',
                      onTap: () {
                        ref.read(settingsProvider.notifier).setVisible(false);
                        context.go('/profile');
                        showToast(context, 'Your visibility is paused.');
                      },
                    ),
                    if (premium)
                      MenuRow(
                        label: 'End Premium preview',
                        detail: 'Return to blurred Likes You',
                        icon: 'spark',
                        onTap: () {
                          ref.read(premiumProvider.notifier).end();
                          context.go('/likes');
                          showToast(context, 'Premium preview ended. Your matches and chats stay open.');
                        },
                      ),
                    MenuRow(
                      label: 'Log out',
                      icon: 'back',
                      onTap: () {
                        ref.read(sessionProvider.notifier).logOut();
                        showToast(context, 'Signed out of the demo.');
                      },
                    ),
                    MenuRow(label: 'Delete account', icon: 'close', danger: true, onTap: () => showDeleteAccountSheet(context, ref)),
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
