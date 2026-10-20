import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/rast_colors.dart';
import '../../../core/theme/rast_theme.dart';
import '../../../core/ui/ui.dart';
import '../../discovery/deck_notifier.dart';
import '../../onboarding/preferences_form.dart';
import '../preferences_notifier.dart';

/// Edits are a draft until "Save preferences". Dismissing discards them.
Future<void> showFiltersSheet(BuildContext context, WidgetRef ref) {
  var draft = ref.read(preferencesProvider);
  String? error;
  return showRastSheet<void>(
    context,
    title: 'Your kind of connection.',
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A few preferences. More possibilities.', style: rastStyle(size: 13, weight: 450, height: 1.65, color: sheetContext.colors.body)),
          const SizedBox(height: 23),
          PreferencesForm(value: draft, onChanged: (p) => setState(() => draft = p)),
          FormError(error),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save preferences',
            onPressed: () {
              if (!draft.isValid) {
                setState(() => error = 'Choose at least one dating preference.');
                return;
              }
              ref.read(preferencesProvider.notifier).replace(Preferences(interests: draft.interests, minAge: draft.minAge, maxAge: draft.maxAge));
              ref.read(deckProvider.notifier).resetPhoto();
              Navigator.of(sheetContext).pop();
              showToast(context, 'Your dating preferences have been updated.');
            },
          ),
        ],
      ),
    ),
  );
}
