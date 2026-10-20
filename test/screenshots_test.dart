// Renders key screens to PNG files for visual review. Skipped unless
// RAST_SHOTS points at an output directory:
//   RAST_SHOTS=/path/to/dir flutter test test/screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/theme/appearance.dart';
import 'package:rast/features/discovery/deck_notifier.dart';
import 'package:rast/features/premium/premium_notifier.dart';

import 'helpers/app.dart';

final String? outDir = Platform.environment['RAST_SHOTS'];

Future<void> shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });
  await tester.pump();
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(() => layer.toImage(view.paintBounds, pixelRatio: 2));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  if (outDir == null) return;

  for (final appearance in [Appearance.light, Appearance.dark]) {
    final suffix = appearance.name;
    testWidgets('screens ($suffix)', (tester) async {
      final c = await testContainer(prefs: {'rast.appearance': appearance.name});
      await pumpRast(tester, c);
      await shoot(tester, '01-welcome-$suffix');

      makeActiveMember(c, introComplete: false);
      await tester.pumpAndSettle();
      await shoot(tester, '02-intro-$suffix');

      final c2 = await testContainer(prefs: {'rast.appearance': appearance.name});
      makeActiveMember(c2);
      await pumpRast(tester, c2);
      c2.read(deckProvider.notifier).focus('p1');
      await tester.pumpAndSettle();
      await shoot(tester, '03-discover-$suffix');

      routerOf(c2).go('/likes');
      await tester.pumpAndSettle();
      await shoot(tester, '04-likes-$suffix');

      routerOf(c2).push('/likes/plus');
      await tester.pumpAndSettle();
      await shoot(tester, '05-plus-$suffix');
      routerOf(c2).pop();

      c2.read(premiumProvider.notifier).activatePreview();
      routerOf(c2).go('/likes');
      await tester.pumpAndSettle();
      await shoot(tester, '06-likes-premium-$suffix');

      routerOf(c2).go('/matches/p1');
      await tester.pumpAndSettle();
      await shoot(tester, '07-match-$suffix');

      routerOf(c2).go('/chats');
      await tester.pumpAndSettle();
      await shoot(tester, '08-chats-$suffix');

      routerOf(c2).push('/chats/t1');
      await tester.pumpAndSettle();
      await shoot(tester, '09-conversation-$suffix');
      routerOf(c2).pop();

      routerOf(c2).go('/profile');
      await tester.pumpAndSettle();
      await shoot(tester, '10-profile-$suffix');

      routerOf(c2).go('/profile/location');
      await tester.pumpAndSettle();
      await shoot(tester, '11-location-$suffix');

      routerOf(c2).go('/profile/safety');
      await tester.pumpAndSettle();
      await shoot(tester, '12-safety-$suffix');

      routerOf(c2).go('/discover');
      await tester.pumpAndSettle();
      routerOf(c2).push('/discover/people/p1');
      await tester.pumpAndSettle();
      await shoot(tester, '13-detail-$suffix');
      routerOf(c2).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Dating preferences'));
      await tester.pumpAndSettle();
      await shoot(tester, '14-filters-sheet-$suffix');
    });
  }

  testWidgets('onboarding screens', (tester) async {
    final c = await testContainer();
    await pumpRast(tester, c);
    routerOf(c).go('/auth/phone');
    await tester.pumpAndSettle();
    await shoot(tester, '20-phone');
    routerOf(c).push('/auth/verify');
    await tester.pumpAndSettle();
    await shoot(tester, '21-verify');
    routerOf(c).push('/setup/about');
    await tester.pumpAndSettle();
    await shoot(tester, '22-about');
    routerOf(c).push('/setup/preferences');
    await tester.pumpAndSettle();
    await shoot(tester, '23-preferences');
    routerOf(c).push('/setup/photos');
    await tester.pumpAndSettle();
    await shoot(tester, '24-photos');
    routerOf(c).push('/setup/location');
    await tester.pumpAndSettle();
    await shoot(tester, '25-location');
  });
}
