import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../profile/profile_notifier.dart';
import 'onboarding_scaffold.dart';

/// Parses typed age. Returns the error string or null when valid.
String? validateAgeInput(String raw) {
  final text = raw.trim();
  final n = int.tryParse(text);
  if (text.isEmpty || n == null || n > 130) {
    final asNumber = double.tryParse(text);
    if (asNumber != null && asNumber.isFinite && asNumber < 18 && text.isNotEmpty) {
      return 'You must be 18 or older to use rast.';
    }
    return 'Enter a valid whole-number age from 18 to 130.';
  }
  if (n < 18) return 'You must be 18 or older to use rast.';
  return null;
}

class AboutYouPage extends ConsumerStatefulWidget {
  const AboutYouPage({super.key});

  @override
  ConsumerState<AboutYouPage> createState() => _AboutYouPageState();
}

class _AboutYouPageState extends ConsumerState<AboutYouPage> {
  late final TextEditingController _age;
  late final TextEditingController _custom;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider);
    _age = TextEditingController(text: p.age?.toString() ?? '');
    _custom = TextEditingController(text: p.customGender);
  }

  @override
  void dispose() {
    _age.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _continue() {
    final profile = ref.read(profileProvider);
    final ageError = validateAgeInput(_age.text);
    if (ageError != null) {
      setState(() => _error = ageError);
      return;
    }
    if (profile.gender == null) {
      setState(() => _error = 'Select your gender to continue.');
      return;
    }
    if (profile.gender == Gender.self && _custom.text.trim().isEmpty) {
      setState(() => _error = 'Describe your gender in your own words.');
      return;
    }
    setState(() => _error = null);
    final notifier = ref.read(profileProvider.notifier);
    notifier.setAge(int.parse(_age.text.trim()));
    notifier.setCustomGender(_custom.text.trim());
    context.push('/setup/preferences');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profile = ref.watch(profileProvider);
    return OnboardingScaffold(
      headerTitle: 'About you',
      step: 2,
      kicker: 'THE ESSENTIALS',
      headline: 'A little\nabout you.',
      copy: "Your age and identity.\nWe'll ask who you want to meet next.",
      body: [
        const FieldLabel('Your age'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: c.inputFill,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: c.inputBorder),
          ),
          padding: const EdgeInsets.only(right: 20),
          child: Row(
            children: [
              SizedBox(
                width: 135,
                child: TextField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9. ]')), LengthLimitingTextInputFormatter(6)],
                  style: rastStyle(size: 40, weight: 750, letterSpacing: -1.5, color: c.text),
                  cursorColor: c.accent,
                  decoration: InputDecoration(
                    hintText: '28',
                    hintStyle: rastStyle(size: 40, weight: 750, letterSpacing: -1.5, color: c.isDark ? const Color(0xFF94909C) : const Color(0xFFC4C4CC)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    semanticCounterText: '',
                  ),
                ),
              ),
              Text('years old', style: rastStyle(size: 13, weight: 450, color: c.isDark ? c.body : const Color(0xFFB5B5BF))),
            ],
          ),
        ),
        const FormHelp('You must be 18 or older. Ages 99 and up display as 99+.'),
        const SizedBox(height: 28),
        const FieldLabel('Your gender'),
        const SizedBox(height: 12),
        OptionGroup(
          children: [
            for (final g in Gender.values)
              OptionChip(
                label: g.label,
                selected: profile.gender == g,
                onTap: () => ref.read(profileProvider.notifier).setGender(g),
              ),
          ],
        ),
        if (profile.gender == Gender.self) ...[
          const SizedBox(height: 12),
          RastTextField(
            controller: _custom,
            hint: 'In your own words',
            maxLength: 50,
            semanticLabel: 'Describe your gender',
            onChanged: (v) => ref.read(profileProvider.notifier).setCustomGender(v),
          ),
        ],
        const SizedBox(height: 12),
        OptionCheck(
          label: 'Show my gender on my profile.',
          value: profile.showGender,
          onChanged: (v) => ref.read(profileProvider.notifier).setShowGender(v),
        ),
        FormError(_error),
      ],
      footer: PrimaryButton(label: 'Continue', onPressed: _continue),
    );
  }
}
