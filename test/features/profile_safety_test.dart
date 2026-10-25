import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/models/models.dart';
import 'package:rast/core/ui/ui.dart';
import 'package:rast/features/auth/session_notifier.dart';
import 'package:rast/features/chat/threads_notifier.dart';
import 'package:rast/features/discovery/eligibility.dart';
import 'package:rast/features/profile/profile_notifier.dart';
import 'package:rast/features/profile/settings_notifier.dart';
import 'package:rast/features/safety/safety_actions.dart';
import 'package:rast/features/safety/safety_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app.dart';

void main() {
  testWidgets('profile shows identity, preferences and reacts to visibility', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c, initialLocation: '/profile');
    expect(find.text('Your profile'), findsOneWidget);
    expect(find.textContaining('28'), findsWidgets);
    expect(find.text('Good being you.'), findsOneWidget);
    expect(find.text('Open to encounters'), findsOneWidget);
    expect(find.text('23–36 years · Everyone'), findsOneWidget);
    expect(find.text('30 sec · 2 hours reveal delay'), findsOneWidget);
    expect(find.text('Match your device'), findsOneWidget);
    c.read(profileProvider.notifier).setShowGender(true);
    c.read(settingsProvider.notifier).setVisible(false);
    await tester.pumpAndSettle();
    expect(find.text('Woman'), findsOneWidget);
    expect(find.text('Visibility paused'), findsOneWidget);
  });

  testWidgets('appearance sheet switches theme and persists', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c, initialLocation: '/profile');
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Your kind of light.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('appearance-dark')));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Your kind of light.'))).brightness, Brightness.dark);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('rast.appearance'), 'dark');
  });

  testWidgets('location settings persist interval and delay, toggle visibility', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c, initialLocation: '/profile/location');
    expect(find.text('You set\nthe pace.'), findsOneWidget);
    await tester.tap(find.text('45 sec'));
    await tester.pump();
    expect(c.read(settingsProvider).intervalSeconds, 45);
    expect((await SharedPreferences.getInstance()).getInt('rast.interval'), 45);
    await tester.ensureVisible(find.text('1 day'));
    await tester.tap(find.text('1 day'));
    await tester.pump();
    expect(c.read(settingsProvider).delayHours, 24);
    await tester.ensureVisible(find.byType(RastSwitch));
    await tester.tap(find.byType(RastSwitch));
    await tester.pump();
    expect(c.read(settingsProvider).visible, isFalse);
    expect(find.text('Visibility paused. Your existing chats stay open.'), findsOneWidget);
    await finishToasts(tester);
  });

  testWidgets('notifications sheet toggles the preference', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c, initialLocation: '/profile');
    await tester.ensureVisible(find.text('Notifications'));
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(RastSwitch));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).notifications, isFalse);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('edit photos: removing one disables Save and pauses discovery', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c, initialLocation: '/profile');
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/profile/photos');
    await tester.tap(find.byKey(const Key('photo-remove-1')));
    await tester.pumpAndSettle();
    expect(tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Save photos')).onPressed, isNull);
    expect(c.read(eligiblePeopleProvider), isEmpty);
    routerOf(c).go('/discover');
    await tester.pumpAndSettle();
    expect(find.text('Your photos come first.'), findsOneWidget);
    await tester.tap(find.text('Complete your photos'));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/profile/photos');
  });

  testWidgets('safety page: report keeps or removes the connection', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c, initialLocation: '/chats/t1');
    await tester.tap(find.bySemanticsLabel('Conversation options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report profile'));
    await tester.pumpAndSettle();
    expect(find.text('What would you like to report?'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Complete report')).onPressed, isNull);
    expect(find.text('Also block and permanently remove this connection.'), findsOneWidget);
    await tester.tap(find.text('Scam or spam'));
    await tester.pumpAndSettle();
    // Uncheck "also block".
    await tester.tap(find.text('Also block and permanently remove this connection.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete report'));
    await tester.pumpAndSettle();
    expect(find.text('Report saved in this preview. No real report was sent.'), findsOneWidget);
    expect(c.read(threadsProvider.notifier).byPerson('p3'), isNotNull);
    expect(c.read(safetyProvider).hasReport('p3'), isTrue);
    expect(currentPath(c), '/chats/t1');
    await finishToasts(tester);

    await tester.tap(find.bySemanticsLabel('Conversation options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harassment or inappropriate behaviour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete report'));
    await tester.pumpAndSettle();
    expect(find.text('Report saved and profile blocked in this preview. No real report was sent.'), findsOneWidget);
    expect(c.read(threadsProvider.notifier).byPerson('p3'), isNull);
    expect(c.read(safetyProvider).blocked, contains('p3'));
    expect(c.read(safetyProvider).disconnected, contains('p3'));
    expect(currentPath(c), '/chats');
    await finishToasts(tester);
  });

  testWidgets('block a stranger from Discover then unblock from Safety', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c);
    final id = c.read(currentPersonProvider)!.id;
    await tester.tap(find.bySemanticsLabel('Profile options'));
    await tester.pumpAndSettle();
    expect(find.text('Remove connection'), findsNothing);
    await tester.tap(find.text('Block profile'));
    await tester.pumpAndSettle();
    expect(find.text('Block this profile?'), findsOneWidget);
    await tester.tap(find.widgetWithText(PrimaryButton, 'Block profile'));
    await tester.pumpAndSettle();
    expect(c.read(safetyProvider).blocked, contains(id));
    expect(c.read(safetyProvider).disconnected, isNot(contains(id)));
    expect(c.read(currentPersonProvider)?.id, isNot(id));
    await finishToasts(tester);

    routerOf(c).go('/profile/safety');
    await tester.pumpAndSettle();
    expect(find.text('1 people'), findsOneWidget);
    await tester.tap(find.text('Blocked profiles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();
    expect(find.text('Profile unblocked.'), findsOneWidget);
    expect(c.read(safetyProvider).blocked, isEmpty);
    expect(c.read(eligiblePeopleProvider).any((p) => p.id == id), isTrue);
    await finishToasts(tester);
  });

  testWidgets('removed connections list offers Report and no restore', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    c.read(safetyActionsProvider).removePerson('p3');
    await pumpRast(tester, c, initialLocation: '/profile/safety');
    expect(find.text('1 removed · No future matching'), findsOneWidget);
    await tester.tap(find.text('Removed connections'));
    await tester.pumpAndSettle();
    expect(find.text('26 · Connection removed'), findsOneWidget);
    expect(find.text('Restore'), findsNothing);
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('What would you like to report?'), findsOneWidget);
    expect(find.text('Also block this profile.'), findsOneWidget);
  });

  testWidgets('delete account clears everything and returns to Welcome', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    c.read(safetyProvider.notifier).block('p1');
    await pumpRast(tester, c, initialLocation: '/profile/safety');
    await tester.ensureVisible(find.text('Delete account'));
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete demo account'));
    await tester.pumpAndSettle();
    expect(c.read(sessionProvider).phase, SessionPhase.signedOut);
    expect(currentPath(c), '/welcome');
    final sp = await SharedPreferences.getInstance();
    expect(sp.getStringList('rast.safety.blocked'), isNull);
    expect(sp.getString('rast.intro'), isNull);
    expect(sp.getString('rast.profile.birthDate'), isNull);
    await finishToasts(tester);
  });

  testWidgets('log out from Safety returns to Welcome and keeps safety state', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    c.read(safetyProvider.notifier).block('p1');
    await pumpRast(tester, c, initialLocation: '/profile/safety');
    await tester.ensureVisible(find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/welcome');
    expect(c.read(safetyProvider).blocked, {'p1'});
    await finishToasts(tester);
  });
}
