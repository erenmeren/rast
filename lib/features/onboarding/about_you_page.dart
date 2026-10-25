import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/rules/rules.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../profile/profile_notifier.dart';
import 'onboarding_scaffold.dart';

/// Typed day, month and four-digit year as a UTC calendar date, or null when
/// the fields do not form a real date.
DateTime? parseBirthDate(String day, String month, String year) {
  final d = int.tryParse(day.trim());
  final m = int.tryParse(month.trim());
  final y = int.tryParse(year.trim());
  if (d == null || m == null || y == null || year.trim().length != 4) return null;
  if (m < 1 || m > 12 || d < 1) return null;
  final date = DateTime.utc(y, m, d);
  if (date.month != m || date.day != d) return null; // 31 February rolls over
  return date;
}

/// Returns the error string or null when the birth date is acceptable on [today].
String? validateBirthDateInput(String day, String month, String year, DateTime today) {
  final date = parseBirthDate(day, month, year);
  if (date == null) return 'Enter your birth date as day, month and year.';
  final age = ageOn(date, today);
  if (date.isAfter(today) || age > maxPlausibleAge) return 'Enter a valid birth date.';
  if (age < minAge) return 'You must be 18 or older to use rast.';
  return null;
}

class AboutYouPage extends ConsumerStatefulWidget {
  const AboutYouPage({super.key});

  @override
  ConsumerState<AboutYouPage> createState() => _AboutYouPageState();
}

class _AboutYouPageState extends ConsumerState<AboutYouPage> {
  late final TextEditingController _day;
  late final TextEditingController _month;
  late final TextEditingController _year;
  late final TextEditingController _custom;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider);
    final b = p.birthDate;
    _day = TextEditingController(text: b?.day.toString() ?? '');
    _month = TextEditingController(text: b?.month.toString() ?? '');
    _year = TextEditingController(text: b?.year.toString() ?? '');
    _custom = TextEditingController(text: p.customGender);
  }

  @override
  void dispose() {
    _day.dispose();
    _month.dispose();
    _year.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _continue() {
    final profile = ref.read(profileProvider);
    final dateError = validateBirthDateInput(_day.text, _month.text, _year.text, DateTime.now().toUtc());
    if (dateError != null) {
      setState(() => _error = dateError);
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
    notifier.setBirthDate(parseBirthDate(_day.text, _month.text, _year.text));
    notifier.setCustomGender(_custom.text.trim());
    context.push('/setup/preferences');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    return OnboardingScaffold(
      headerTitle: 'About you',
      step: 2,
      kicker: 'THE ESSENTIALS',
      headline: 'A little\nabout you.',
      copy: "Your birth date and identity.\nWe'll ask who you want to meet next.",
      body: [
        const FieldLabel('Your birth date'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(flex: 2, child: _DateField(controller: _day, hint: 'DD', label: 'Day', digits: 2)),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: _DateField(controller: _month, hint: 'MM', label: 'Month', digits: 2)),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: _DateField(controller: _year, hint: 'YYYY', label: 'Year', digits: 4)),
          ],
        ),
        const FormHelp('You must be 18 or older. Your age is shown, never your birth date. Ages 99 and up display as 99+.'),
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

class _DateField extends StatelessWidget {
  const _DateField({required this.controller, required this.hint, required this.label, required this.digits});

  final TextEditingController controller;
  final String hint;
  final String label;
  final int digits;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.inputFill,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: c.inputBorder),
      ),
      child: Semantics(
        label: label,
        textField: true,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(digits)],
          style: rastStyle(size: 28, weight: 750, letterSpacing: -1, color: c.text),
          cursorColor: c.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: rastStyle(size: 28, weight: 750, letterSpacing: -1, color: c.isDark ? const Color(0xFF94909C) : const Color(0xFFC4C4CC)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            semanticCounterText: '',
          ),
        ),
      ),
    );
  }
}
