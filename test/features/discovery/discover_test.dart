import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/models/models.dart';
import 'package:rast/core/ui/ui.dart';
import 'package:rast/features/discovery/deck_notifier.dart';
import 'package:rast/features/discovery/eligibility.dart';
import 'package:rast/features/discovery/profile_card.dart';
import 'package:rast/features/profile/preferences_notifier.dart';
import 'package:rast/features/profile/settings_notifier.dart';
import 'package:rast/features/safety/safety_notifier.dart';

import '../../helpers/app.dart';

void main() {
  testWidgets('deck shows the first eligible person and pages the album', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c);
    final first = c.read(currentPersonProvider)!;
    expect(find.text('Discover'), findsWidgets);
    expect(find.text('A familiar stranger.'), findsOneWidget);
    expect(find.text(first.age.toString()), findsOneWidget);
    expect(find.byKey(const Key('photo-indicator-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('card-next')));
    await tester.pump();
    expect(find.byKey(const Key('photo-indicator-1')), findsOneWidget);
    expect(c.read(currentPersonProvider)!.id, first.id);
    await tester.tap(find.byKey(const Key('card-prev')));
    await tester.pump();
    expect(find.byKey(const Key('photo-indicator-0')), findsOneWidget);
  });

  testWidgets('pass advances, rewind restores, blocked passes are skipped', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c);
    final first = c.read(currentPersonProvider)!.id;
    Opacity rewindOpacity() => tester.widget<Opacity>(find.descendant(of: find.byKey(const Key('action-rewind')), matching: find.byType(Opacity)).first);
    expect(rewindOpacity().opacity, 0.4);
    await tester.tap(find.bySemanticsLabel('Pass profile'));
    await tester.pumpAndSettle();
    expect(c.read(currentPersonProvider)!.id, isNot(first));
    expect(rewindOpacity().opacity, 1);
    await tester.tap(find.bySemanticsLabel('Rewind last pass'));
    await tester.pumpAndSettle();
    expect(find.text('Your last pass has been undone.'), findsOneWidget);
    expect(c.read(currentPersonProvider)!.id, first);

    await tester.tap(find.bySemanticsLabel('Pass profile'));
    await tester.pumpAndSettle();
    c.read(safetyProvider.notifier).block(first);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Rewind last pass'));
    await tester.pumpAndSettle();
    expect(find.text('No passes to rewind yet.'), findsOneWidget);
    await finishToasts(tester);
  });

  testWidgets('a long drag right likes; a mutual like opens the match moment', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c);
    // Put a person who likes us on top.
    final deck = c.read(deckProvider.notifier);
    deck.focus('p1');
    await tester.pumpAndSettle();
    expect(c.read(currentPersonProvider)!.id, 'p1');
    await tester.drag(find.byType(ProfileCard), const Offset(140, 0));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/matches/p1');
    expect(c.read(deckProvider).liked, contains('p1'));
  });

  testWidgets('a short drag snaps back and does not page the photo', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c);
    final id = c.read(currentPersonProvider)!.id;
    await tester.drag(find.byType(ProfileCard), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(c.read(currentPersonProvider)!.id, id);
    expect(find.byKey(const Key('photo-indicator-0')), findsOneWidget);
    expect(currentPath(c), '/discover');
  });

  testWidgets('like button on a non-mutual person sends a like and stays on Discover', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c);
    c.read(deckProvider.notifier).focus('p4');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Like profile'));
    await tester.pumpAndSettle();
    expect(find.text('Like sent. A mutual like starts a conversation.'), findsOneWidget);
    expect(currentPath(c), '/discover');
    expect(c.read(currentPersonProvider)!.id, isNot('p4'));
    await finishToasts(tester);
  });

  testWidgets('empty states distinguish paused, no location and caught up', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c);
    c.read(settingsProvider.notifier).setVisible(false);
    await tester.pumpAndSettle();
    expect(find.text('Taking a little breather.'), findsOneWidget);
    await tester.tap(find.text('Resume encounters'));
    await tester.pumpAndSettle();
    expect(find.text('Taking a little breather.'), findsNothing);

    c.read(settingsProvider.notifier).setLocation(false);
    await tester.pumpAndSettle();
    expect(find.text('Let your paths cross.'), findsOneWidget);
    await tester.tap(find.text('Enable location'));
    await tester.pumpAndSettle();
    expect(find.text('Precise location'), findsOneWidget);
    await tester.tap(find.widgetWithText(PrimaryButton, 'Enable location').last);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).locationEnabled, isTrue);

    c.read(settingsProvider.notifier).setDelay(24);
    await tester.pumpAndSettle();
    expect(find.text("You're all caught up."), findsOneWidget);
    await tester.tap(find.text('Adjust preferences'));
    await tester.pumpAndSettle();
    expect(find.text('Your kind of connection.'), findsOneWidget);
    await finishToasts(tester);
  });

  testWidgets('filters sheet discards on dismiss and applies on save', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c);
    await tester.tap(find.bySemanticsLabel('Dating preferences'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Women'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(c.read(preferencesProvider).interests, {Interest.everyone});

    await tester.tap(find.bySemanticsLabel('Dating preferences'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Women'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
    expect(c.read(preferencesProvider).interests, {Interest.women});
    expect(find.text('Your dating preferences have been updated.'), findsOneWidget);
    expect(c.read(eligiblePeopleProvider).any((p) => p.id == 'p2'), isFalse);
    await finishToasts(tester);
  });

  testWidgets('person detail shows like, and unavailable for a blocked id', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c);
    final id = c.read(currentPersonProvider)!.id;
    await tester.tap(find.bySemanticsLabel('View profile'));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/discover/people/$id');
    expect(find.text('Like profile'), findsOneWidget);
    expect(find.text('A real-life crossing.\nA new possibility.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next photo'));
    await tester.pump();
    expect(find.text('2 / 4'), findsOneWidget);
    await tester.tap(find.text('Pass for now'));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/discover');
    expect(c.read(deckProvider).passed, contains(id));

    c.read(safetyProvider.notifier).block('p5');
    routerOf(c).push('/discover/people/p5');
    await tester.pumpAndSettle();
    expect(find.text('This profile is unavailable.'), findsOneWidget);
    await tester.tap(find.text('Back to Discover'));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/discover');
    await finishToasts(tester);
  });

  testWidgets('How encounters work button opens the optional story', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c);
    await tester.tap(find.bySemanticsLabel('How encounters work'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(currentPath(c), '/profile/how-it-works');
    expect(find.text('Back to Profile'), findsOneWidget);
  });
}
