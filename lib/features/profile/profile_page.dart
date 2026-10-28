import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/rules/rules.dart';
import '../../core/theme/appearance.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../discovery/eligibility.dart';
import '../premium/premium_notifier.dart';
import 'preferences_notifier.dart';
import 'profile_notifier.dart';
import 'settings_notifier.dart';
import 'sheets/appearance_sheet.dart';
import 'sheets/filters_sheet.dart';
import 'sheets/notifications_sheet.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final profile = ref.watch(profileProvider);
    final prefs = ref.watch(preferencesProvider);
    final settings = ref.watch(settingsProvider);
    final premium = ref.watch(premiumProvider);
    final appearance = ref.watch(appearanceProvider);
    final active = ref.watch(discoveryActiveProvider);
    final n = profile.photoCount;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(action: 'settings', premium: premium, onAction: () => context.go('/profile/location')),
            Expanded(
              child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitle(title: 'Your profile'),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.accent, width: 2)),
                      child: Avatar(profile.primaryPhoto, size: 73),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: profile.age == null ? '—' : ageLabel(profile.age!),
                              children: [TextSpan(text: '  years old', style: rastStyle(size: 13, weight: 500, letterSpacing: 0, color: c.body))],
                            ),
                            style: rastStyle(size: 34, weight: 800, height: 1, letterSpacing: -1.3, color: c.text),
                          ),
                          const SizedBox(height: 6),
                          Text(profile.genderDisplay ?? 'Good being you.', style: rastStyle(size: 12, weight: 450, color: c.body)),
                          const SizedBox(height: 10),
                          Pill(
                            label: active ? 'Open to encounters' : 'Visibility paused',
                            accent: active,
                            dot: active,
                            onTap: () => context.go('/profile/location'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.card),
                  onTap: () => context.push('/profile/plus'),
                  child: Container(
                    padding: const EdgeInsets.all(Space.l),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.card),
                      gradient: LinearGradient(colors: [c.plusGradientStart, c.plusGradientEnd]),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: c.isDark ? const Color(0x66653A2F) : const Color(0x9EFFFFFF), borderRadius: BorderRadius.circular(11)),
                          child: Center(child: RastIcon('spark', size: 21, color: c.accent)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('rast Plus', style: rastStyle(size: 18, weight: 800, letterSpacing: -0.4, color: c.onPlusStrong)),
                              const SizedBox(height: 5),
                              Text(premium ? 'Your Premium preview is active.' : 'See who already likes you.', style: rastStyle(size: 12, weight: 450, color: c.onPlusSoft)),
                            ],
                          ),
                        ),
                        RastIcon('arrow', size: 17, color: c.onPlusStrong),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text.rich(
                    TextSpan(text: 'Your photos', children: [TextSpan(text: '  $n/4', style: rastStyle(size: 9, weight: 500, letterSpacing: 0, color: c.body))]),
                    style: rastStyle(size: 11, weight: 700, color: c.label),
                  ),
                  TextLinkButton(label: 'Edit', size: 11, color: c.accent, onPressed: () => context.push('/profile/photos')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                        child: Container(
                          height: 92,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            color: profile.photos[i] == null ? c.raised : null,
                            border: profile.photos[i] == null ? Border.all(color: c.placeholder) : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: profile.photos[i] == null
                              ? Center(child: Text('+', style: rastStyle(size: 13, weight: 500, color: c.placeholder)))
                              : PhotoImage(profile.photos[i]!, alignment: const Alignment(0, -0.32)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              MenuRow(label: 'Dating preferences', detail: prefs.summary, icon: 'sliders', onTap: () => showFiltersSheet(context, ref)),
              MenuRow(label: 'Location & visibility', detail: '${intervalLabel(settings.intervalSeconds)} · ${delayLabel(settings.delayHours)} reveal delay', icon: 'locate', onTap: () => context.go('/profile/location')),
              MenuRow(label: 'Appearance', detail: appearance == Appearance.system ? 'Match your device' : appearanceLabel(appearance), icon: 'moon', onTap: () => showAppearanceSheet(context, ref)),
              MenuRow(label: 'How it works', detail: 'See how a crossing becomes a connection', icon: 'route', onTap: () => context.go('/profile/how-it-works')),
              MenuRow(label: 'Notifications', detail: settings.anyNotify ? 'On' : 'Off', icon: 'bell', onTap: () => showNotificationsSheet(context, ref)),
              MenuRow(label: 'Safety & account', detail: 'Your boundaries matter', icon: 'shield', onTap: () => context.go('/profile/safety')),
              const SizedBox(height: 26),
              Center(child: Text('rast · A LITTLE CLOSER', style: rastStyle(size: 8, weight: 500, letterSpacing: 1.2, color: c.body))),
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
