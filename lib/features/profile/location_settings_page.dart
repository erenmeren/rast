import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/rules/rules.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import 'settings_notifier.dart';
import 'sheets/location_sheet.dart';

/// Location update target, reveal delay, visibility and location access.
class LocationSettingsPage extends ConsumerWidget {
  const LocationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SubHeader(title: 'Location & visibility', onBack: () => context.canPop() ? context.pop() : context.go('/profile')),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Semantics(header: true, child: Text('You set\nthe pace.', style: rastStyle(size: 40, weight: 800, height: 1.1, letterSpacing: -1.5, color: c.text))),
                    const SizedBox(height: 12),
                    Text('Your encounters. Your timing.', style: rastStyle(size: 14, weight: 450, color: c.isDark ? c.body : const Color(0xFF777783))),
                    const SizedBox(height: 23),
                    _Section(
                      icon: 'locate',
                      title: 'Location update target',
                      children: [
                        TimingGrid<int>(
                          values: updateIntervalSeconds,
                          selected: s.intervalSeconds,
                          label: intervalLabel,
                          onSelect: notifier.setInterval,
                          semanticLabel: 'Location update target',
                        ),
                        const SizedBox(height: 11),
                        Text('Choose a target from 15 seconds to 2 minutes. Shorter intervals may use more battery; actual updates depend on your phone.', style: _copy(c)),
                      ],
                    ),
                    _Section(
                      icon: 'clock',
                      title: 'When should you appear?',
                      children: [
                        TimingGrid<int>(
                          values: revealDelayHours,
                          selected: s.delayHours,
                          label: delayChipLabel,
                          note: (h) => h == 2 ? 'DEFAULT' : h == 0 ? 'NO WAIT' : h == 24 ? '24 HOURS' : '',
                          minHeight: 59,
                          onSelect: notifier.setDelay,
                          semanticLabel: 'Profile reveal delay',
                        ),
                        const SizedBox(height: 11),
                        Text('Appear any time from immediately to 1 day after crossing paths. The default is 2 hours.', style: _copy(c)),
                        const SizedBox(height: 13),
                        const SettingTip(icon: 'shield', text: 'The longer of your two delays always applies. Discover mixes the order, so it never shows a timeline of your day.'),
                      ],
                    ),
                    _Section(
                      children: [
                        ToggleRow(
                          title: 'Open to encounters',
                          text: 'Switch off to pause new encounters.',
                          value: s.visible,
                          onChanged: (v) {
                            notifier.setVisible(v);
                            showToast(context, v ? 'Encounters are back on.' : 'Visibility paused. Your existing chats stay open.');
                          },
                        ),
                      ],
                    ),
                    _Section(
                      children: [
                        Semantics(
                          button: true,
                          child: InkWell(
                            onTap: () => showLocationSheet(context, ref),
                            child: Row(
                              children: [
                                RastIcon('locate', size: 16, color: c.accent),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Location access', style: rastStyle(size: 14, weight: 750, color: c.isDark ? c.label : const Color(0xFF555562)))),
                                Pill(label: s.locationEnabled ? 'Enabled' : 'Off', accent: s.locationEnabled),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TextStyle _copy(RastColors c) => rastStyle(size: 12, weight: 450, height: 1.9, color: c.isDark ? c.body : const Color(0xFF757582));
}

class _Section extends StatelessWidget {
  const _Section({this.icon, this.title, required this.children});
  final String? icon;
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.outline))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[RastIcon(icon!, size: 16, color: c.accent), const SizedBox(width: 8)],
                Text(title!, style: rastStyle(size: 14, weight: 750, color: c.isDark ? c.label : const Color(0xFF555562))),
              ],
            ),
            const SizedBox(height: 15),
          ],
          ...children,
        ],
      ),
    );
  }
}
