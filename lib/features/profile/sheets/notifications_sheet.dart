import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/rast_colors.dart';
import '../../../core/theme/rast_theme.dart';
import '../../../core/ui/ui.dart';
import '../settings_notifier.dart';

/// App-level preference, separate from the OS permission.
Future<void> showNotificationsSheet(BuildContext context, WidgetRef ref) {
  return showRastSheet<void>(
    context,
    title: 'When something clicks.',
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, ref, _) {
        final c = sheetContext.colors;
        final on = ref.watch(settingsProvider).notifications;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hear about new matches and messages.', style: rastStyle(size: 13, weight: 450, height: 1.65, color: c.body)),
            const SizedBox(height: 24),
            ToggleRow(title: 'Matches & messages', text: 'Switch off whenever you want.', value: on, onChanged: ref.read(settingsProvider.notifier).setNotifications),
            const SizedBox(height: 16),
            const SettingTip(icon: 'shield', text: 'Notifications never include an exact encounter location or time.'),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Done', onPressed: () => Navigator.of(sheetContext).pop()),
          ],
        );
      },
    ),
  );
}
