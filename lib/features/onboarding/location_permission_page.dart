import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/ui/ui.dart';
import '../auth/session_notifier.dart';
import 'onboarding_scaffold.dart';

/// Step 5. Both choices finish setup. "Enable location" asks the platform
/// through the location repository (the mock grants at once).
class LocationPermissionPage extends ConsumerWidget {
  const LocationPermissionPage({super.key});

  Future<void> _finish(BuildContext context, WidgetRef ref, {required bool granted}) async {
    if (granted) {
      // precise location, then "allow all the time", then notifications
      granted = await ref.read(locationRepositoryProvider).requestPermissions();
      if (!context.mounted) return;
      if (!granted) showToast(context, 'Location stays off until you allow it all the time in Settings.');
    }
    final problem = ref.read(sessionProvider.notifier).finishSetup(locationGranted: granted);
    if (problem != null) {
      showToast(context, problem.message);
      context.go(problem.route);
    }
    // On success the session phase changes and the router redirects.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingScaffold(
      headerTitle: 'One last thing',
      step: 5,
      headline: 'Out there.\nCloser than ever.',
      copy: 'Meet people you have crossed paths with,\nwithin approximately 20 metres.',
      body: const [
        _Orbit(),
        SizedBox(height: 5),
        FeatureItem(
          icon: 'locate',
          title: 'Catch the everyday encounters',
          text: "Background location helps find crossings even when the app isn't open.",
        ),
        FeatureItem(
          icon: 'shield',
          title: 'Your location stays yours',
          text: 'No exact locations are shared. Profiles appear after 2 hours by default.',
          divider: false,
        ),
      ],
      footer: Column(
        children: [
          PrimaryButton(label: 'Enable location', onPressed: () => _finish(context, ref, granted: true)),
          const SizedBox(height: 4),
          TextLinkButton(label: 'Not now', fullWidth: true, onPressed: () => _finish(context, ref, granted: false)),
        ],
      ),
    );
  }
}

class _Orbit extends StatelessWidget {
  const _Orbit();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ring = c.isDark ? const Color(0xFF704C43) : const Color(0xFFFFD8CC);
    return SizedBox(
      height: 150,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring))),
            Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring))),
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: c.isDark ? c.primary : c.accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: c.accent.withValues(alpha: c.isDark ? 0.25 : 0.19), blurRadius: 22, offset: const Offset(0, 8))],
              ),
              child: const Center(child: RastIcon('locate', size: 35, color: Colors.white)),
            ),
            Positioned(
              left: 75 + 64 - 5,
              top: 75 - 39 - 5,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: c.canvas, width: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
