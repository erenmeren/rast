import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/rast_colors.dart';
import '../../../core/theme/rast_theme.dart';
import '../../../core/ui/ui.dart';
import '../settings_notifier.dart';

/// Explains precise + background access. The mock toggles a flag; the
/// production adapter performs the real permission request and recovery.
Future<void> showLocationSheet(BuildContext context, WidgetRef ref) {
  return showRastSheet<void>(
    context,
    title: 'Let your paths cross.',
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, ref, _) {
        final enabled = ref.watch(settingsProvider).locationEnabled;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location access helps you discover people whose paths cross yours.', style: rastStyle(size: 13, weight: 450, height: 1.65, color: sheetContext.colors.body)),
            const SizedBox(height: 8),
            const FeatureItem(icon: 'locate', title: 'Precise location', text: 'Helps assess encounters within approximately 20 metres.'),
            const FeatureItem(icon: 'clock', title: 'Background location', text: "Helps capture encounters even while the app isn't open.", divider: false),
            const SizedBox(height: 4),
            const SettingTip(icon: 'lock', text: 'Other people never see your exact location on a map.'),
            const SizedBox(height: 20),
            PrimaryButton(
              label: enabled ? 'Turn location off' : 'Enable location',
              onPressed: () async {
                final next = !enabled;
                if (next && !await ref.read(locationRepositoryProvider).requestPermissions()) {
                  if (sheetContext.mounted) showToast(sheetContext, 'Location stays off until you allow it all the time in Settings.');
                  return;
                }
                if (!sheetContext.mounted) return;
                ref.read(settingsProvider.notifier).setLocation(next);
                if (next) ref.read(settingsProvider.notifier).setVisible(true);
                Navigator.of(sheetContext).pop();
                showToast(context, next ? 'Location enabled. Your actual location is not collected in this preview.' : 'Location is off. New encounters are paused.');
              },
            ),
          ],
        );
      },
    ),
  );
}
