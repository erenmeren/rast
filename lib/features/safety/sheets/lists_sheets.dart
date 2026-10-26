import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../discovery/people_directory.dart';
import '../../../core/rules/rules.dart';
import '../../../core/theme/rast_colors.dart';
import '../../../core/theme/rast_theme.dart';
import '../../../core/ui/ui.dart';
import '../../auth/session_notifier.dart';
import '../safety_actions.dart';
import '../safety_notifier.dart';
import 'person_menu_sheet.dart';

Future<void> showBlockedProfilesSheet(BuildContext context, WidgetRef ref) {
  return showRastSheet<void>(
    context,
    title: 'Blocked profiles',
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, ref, _) {
        final c = sheetContext.colors;
        final safety = ref.watch(safetyProvider);
        if (safety.blocked.isEmpty) {
          return Text('You have not blocked any profiles.', style: rastStyle(size: 13, weight: 450, height: 1.65, color: c.body));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final id in safety.blocked)
              if (ref.person(id) case final p?)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.outline))),
                  child: Row(
                    children: [
                      Avatar(p.photo, size: 54),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${p.age} years old', style: rastStyle(size: 15, weight: 750, color: c.isDark ? c.label : const Color(0xFF4A4A56)))),
                      TextLinkButton(
                        label: 'Unblock',
                        onPressed: () {
                          final removed = safety.disconnected.contains(id);
                          ref.read(safetyActionsProvider).unblock(id);
                          showToast(context, removed ? 'Profile unblocked. Your connection stays removed; you cannot match again.' : 'Profile unblocked.');
                        },
                      ),
                    ],
                  ),
                ),
            const FormHelp('Unblocking never restores a removed connection. If you were matched before, you still cannot match again.'),
          ],
        );
      },
    ),
  );
}

Future<void> showRemovedConnectionsSheet(BuildContext context, WidgetRef ref) {
  return showRastSheet<void>(
    context,
    title: 'Removed connections',
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, ref, _) {
        final c = sheetContext.colors;
        final safety = ref.watch(safetyProvider);
        if (safety.disconnected.isEmpty) {
          return Text('No removed connections. If you remove someone, that connection stays closed for good.', style: rastStyle(size: 13, weight: 450, height: 1.65, color: c.body));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('These connections are permanently closed. You will not see or match with each other again.', style: rastStyle(size: 13, weight: 450, height: 1.65, color: c.body)),
            const SizedBox(height: 6),
            for (final id in safety.disconnected)
              if (ref.person(id) case final p?)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.outline))),
                  child: Row(
                    children: [
                      Avatar(p.photo, size: 54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${ageLabel(p.age)} · Connection removed', style: rastStyle(size: 15, weight: 750, color: c.isDark ? c.label : const Color(0xFF4A4A56))),
                            const SizedBox(height: 6),
                            Text(safety.hasReport(id) ? 'Report saved in this preview' : 'No future matching', style: rastStyle(size: 13, weight: 450, color: c.isDark ? c.body : const Color(0xFF7A7A87))),
                          ],
                        ),
                      ),
                      TextLinkButton(
                        label: 'Report',
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          showReportSheet(context, ref, id, returnTo: '/profile/safety');
                        },
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
    ),
  );
}

Future<void> showDeleteAccountSheet(BuildContext context, WidgetRef ref) {
  return showRastSheet<void>(
    context,
    title: 'Delete your account?',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your demo profile, photos, matches and messages will be cleared. There is no real account attached to this preview.', style: rastStyle(size: 13, weight: 450, height: 1.65, color: sheetContext.colors.body)),
        const SizedBox(height: 20),
        PrimaryButton(
          label: ref.read(backendKindProvider) == BackendKind.mock ? 'Delete demo account' : 'Delete my account',
          onPressed: () async {
            Navigator.of(sheetContext).pop();
            try {
              await ref.read(sessionProvider.notifier).deleteAccount();
              if (context.mounted) showToast(context, ref.read(backendKindProvider) == BackendKind.mock ? 'Demo account cleared.' : 'Your account has been deleted.');
            } catch (_) {
              if (context.mounted) showToast(context, 'Your account could not be deleted right now. Check your connection and try again.');
            }
          },
        ),
        const SizedBox(height: 9),
        SecondaryButton(label: 'Keep account', onPressed: () => Navigator.of(sheetContext).pop()),
      ],
    ),
  );
}
