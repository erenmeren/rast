import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../onboarding/onboarding_scaffold.dart';
import '../profile/profile_notifier.dart';
import 'session_notifier.dart';

class VerifyPage extends ConsumerStatefulWidget {
  const VerifyPage({super.key});

  @override
  ConsumerState<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends ConsumerState<VerifyPage> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final ok = await ref.read(authRepositoryProvider).verify(_code.text);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = ref.read(backendKindProvider) == BackendKind.mock
          ? 'That code does not match. Use 246810 for this prototype.'
          : 'That code does not match. Check the SMS and try again.');
      return;
    }
    ref.read(sessionProvider.notifier).markVerified();
    context.push('/setup/about');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profile = ref.watch(profileProvider);
    final number = profile.phone.isEmpty ? '7700 900 123' : profile.phone;
    return OnboardingScaffold(
      headerTitle: 'Verify your number',
      step: 1,
      body: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: c.accentContainer, borderRadius: BorderRadius.circular(19)),
          child: Center(child: RastIcon('chat', size: 28, color: c.accent)),
        ),
        const SizedBox(height: 14),
        Semantics(header: true, child: Text('Check your\nmessages.', style: RastText.setupHeadline(c))),
        const SizedBox(height: 15),
        Text.rich(
          TextSpan(
            text: 'Enter the six-digit code sent to\n',
            children: [
              TextSpan(text: '${profile.dial} $number', style: TextStyle(fontWeight: FontWeight.w700, color: c.text, fontVariations: const [FontVariation('wght', 700)])),
              const TextSpan(text: '.'),
            ],
          ),
          style: rastStyle(size: 13, weight: 450, height: 1.8, color: c.body),
        ),
        const SizedBox(height: 29),
        RastTextField(
          controller: _code,
          label: 'Verification code',
          hint: '· · · · · ·',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          autofillHints: const [AutofillHints.oneTimeCode],
          textAlign: TextAlign.center,
          style: rastStyle(size: 30, weight: 750, letterSpacing: 11, color: c.text),
          onSubmitted: (_) => _verify(),
          semanticLabel: 'Verification code',
        ),
        FormError(_error),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextLinkButton(label: 'Change number', size: 12, onPressed: () => context.pop()),
            TextLinkButton(
              label: 'Send again',
              size: 12,
              onPressed: () => showToast(context, 'Demo verification code: 246810. No SMS is sent.'),
            ),
          ],
        ),
      ],
      footer: Column(
        children: [
          PrimaryButton(label: 'Verify', onPressed: _verify),
          const SizedBox(height: 13),
          Text('One small step closer to your next connection.', textAlign: TextAlign.center, style: RastText.tiny(c)),
        ],
      ),
    );
  }
}
