import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/ui.dart';
import '../profile/preferences_notifier.dart';
import 'onboarding_scaffold.dart';
import 'preferences_form.dart';

class PreferencesPage extends ConsumerStatefulWidget {
  const PreferencesPage({super.key});

  @override
  ConsumerState<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends ConsumerState<PreferencesPage> {
  String? _error;

  void _continue() {
    if (!ref.read(preferencesProvider).isValid) {
      setState(() => _error = 'Choose at least one dating preference.');
      return;
    }
    context.push('/setup/photos');
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    return OnboardingScaffold(
      headerTitle: 'Your preferences',
      step: 3,
      headline: 'Your kind\nof connection.',
      copy: "Tell us who you'd like to meet.\nYou can change this anytime.",
      body: [
        PreferencesForm(value: prefs, onChanged: ref.read(preferencesProvider.notifier).replace),
        FormError(_error),
      ],
      footer: PrimaryButton(label: 'Continue', onPressed: _continue),
    );
  }
}
