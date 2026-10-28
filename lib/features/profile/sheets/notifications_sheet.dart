import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
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
        final settings = ref.watch(settingsProvider);
        final set = ref.read(settingsProvider.notifier).setNotify;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hear about new matches, likes and messages.', style: rastStyle(size: 13, weight: 450, height: 1.65, color: c.body)),
            const SizedBox(height: 24),
            ToggleRow(title: 'New matches', text: 'Someone you crossed paths with likes you back.', value: settings.notifyMatches, onChanged: (v) => set(NotifyKind.matches, v)),
            const SizedBox(height: Space.m),
            ToggleRow(title: 'Likes', text: 'A new like is waiting for you.', value: settings.notifyLikes, onChanged: (v) => set(NotifyKind.likes, v)),
            const SizedBox(height: Space.m),
            ToggleRow(title: 'Messages', text: 'A match wrote to you.', value: settings.notifyMessages, onChanged: (v) => set(NotifyKind.messages, v)),
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
