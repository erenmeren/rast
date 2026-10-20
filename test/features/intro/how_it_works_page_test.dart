import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/models/models.dart';
import 'package:rast/features/auth/session_notifier.dart';
import 'package:rast/features/intro/how_it_works_page.dart';
import 'package:rast/features/intro/intro_notifier.dart';

import '../../helpers/app.dart';

Future<void> pumpStory(WidgetTester tester, {int ms = 100, int times = 1}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

void main() {
  testWidgets('required intro gates until watched, then Start exploring opens Discover', (tester) async {
    final c = await testContainer();
    makeActiveMember(c, introComplete: false);
    await pumpRast(tester, c, settle: false);
    expect(currentPath(c), '/intro');
    expect(find.text('Watch to continue'), findsOneWidget);
    expect(find.text('ONE QUICK INTRODUCTION'), findsOneWidget);
    expect(find.text('Just this once'), findsOneWidget);
    expect(find.text('Life brings you a little closer.'), findsOneWidget);

    await pumpStory(tester, times: 70);
    expect(find.text('The connection goes both ways.'), findsOneWidget);
    expect(find.text('Watch to continue'), findsOneWidget);

    // Backgrounding for a minute must not count.
    final state = tester.state<HowItWorksPageState>(find.byType(HowItWorksPage));
    final before = state.controller.watchedMs;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 60));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(state.controller.watchedMs, before);

    await pumpStory(tester, times: 210);
    expect(find.text('Start exploring'), findsOneWidget);
    expect(find.text('All set. Replay this anytime from Profile.'), findsOneWidget);
    expect(c.read(introProvider), IntroStatus.complete);
    await tester.tap(find.text('Start exploring'));
    await tester.pumpAndSettle();
    expect(c.read(sessionProvider).phase, SessionPhase.active);
    expect(currentPath(c), '/discover');
  });

  testWidgets('pause stops crediting and the story survives a relaunch as pending', (tester) async {
    final c = await testContainer();
    makeActiveMember(c, introComplete: false);
    await pumpRast(tester, c, settle: false);
    await pumpStory(tester, times: 10);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    await pumpStory(tester, times: 50);
    expect(find.text('Life brings you a little closer.'), findsOneWidget);
    expect(c.read(introProvider), IntroStatus.pending);
  });

  testWidgets('optional replay has chapters and Back to Profile', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c, initialLocation: '/profile/how-it-works', settle: false);
    expect(find.text('Back to Profile'), findsOneWidget);
    expect(find.text('SMALL WORLD. GOOD TIMING.'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
    await tester.tap(find.text('Give it time'));
    await tester.pump();
    expect(find.text('A little space. A little time.'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    await tester.tap(find.text('Back to Profile'));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/profile');
  });

  testWidgets('reduced motion still requires the full viewing time', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final c = await testContainer();
    makeActiveMember(c, introComplete: false);
    await pumpRast(tester, c, settle: false);
    expect(find.text('Reduced motion is on. The five scenes advance automatically.'), findsOneWidget);
    await pumpStory(tester, times: 100);
    expect(find.text('Watch to continue'), findsOneWidget);
    await pumpStory(tester, times: 180);
    expect(find.text('Start exploring'), findsOneWidget);
  });
}
