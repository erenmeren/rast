import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../onboarding/onboarding_scaffold.dart';
import '../profile/profile_notifier.dart';
import '../profile/sheets/policy_sheets.dart';

const List<String> dialCodes = ['+44', '+1', '+90', '+49'];

/// Validation copied from the prototype. Returns an error or null.
String? validatePhone(String dial, String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (dial == '+90') {
    return RegExp(r'^[1-9]\d{9}$').hasMatch(digits) ? null : 'Enter a 10-digit number without the leading zero.';
  }
  return RegExp(r'^\d{7,14}$').hasMatch(digits) ? null : 'Enter a valid phone number.';
}

class PhonePage extends ConsumerStatefulWidget {
  const PhonePage({super.key});

  @override
  ConsumerState<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends ConsumerState<PhonePage> {
  late final TextEditingController _phone;
  late String _dial;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _phone = TextEditingController(text: profile.phone);
    _dial = dialCodes.contains(profile.dial) ? profile.dial : '+44';
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = validatePhone(_dial, _phone.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    ref.read(profileProvider.notifier).setPhone(_dial, _phone.text.trim());
    await ref.read(authRepositoryProvider).sendCode(_dial, _phone.text.trim());
    if (!mounted) return;
    showToast(context, 'Demo SMS code: 246810. No real SMS is sent.');
    context.push('/auth/verify');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return OnboardingScaffold(
      headerTitle: 'Getting started',
      step: 1,
      onBack: () => context.go('/welcome'),
      kicker: "LET'S MAKE THIS SIMPLE",
      headline: 'Your number.\nYour way in.',
      copy: 'We will send you a code.\nNo passwords to remember.',
      body: [
        const FieldLabel('Phone number'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 92,
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: c.inputFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.inputBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _dial,
                  isExpanded: true,
                  dropdownColor: c.sheet,
                  style: RastText.input(c),
                  icon: RastIcon('chevron', size: 12, color: c.body),
                  items: [for (final d in dialCodes) DropdownMenuItem(value: d, child: Text(d))],
                  onChanged: (v) => setState(() => _dial = v ?? _dial),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: RastTextField(
                controller: _phone,
                hint: '7700 900 123',
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                maxLength: 18,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                semanticLabel: 'Phone number',
              ),
            ),
          ],
        ),
        const FormHelp('Your number is never shown on your profile.'),
        FormError(_error),
        const SizedBox(height: 22),
        const InfoBox(icon: 'lock', strong: 'A private first step.', text: 'Your phone number is used to help verify your account.'),
      ],
      footer: Column(
        children: [
          PrimaryButton(label: 'Send code', onPressed: _submit),
          const SizedBox(height: 13),
          Text.rich(
            TextSpan(
              text: 'By continuing, you agree to our ',
              children: [
                WidgetSpan(child: _InlineLink('Terms', () => showTermsSheet(context))),
                const TextSpan(text: '\nand '),
                WidgetSpan(child: _InlineLink('Privacy information', () => showPrivacySheet(context))),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
            style: RastText.tiny(c),
          ),
        ],
      ),
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = RastText.tiny(context.colors);
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: style.copyWith(decoration: TextDecoration.underline, decorationColor: style.color)),
    );
  }
}
