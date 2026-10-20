import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/ui/ui.dart';
import 'package:rast/features/chat/conversation_page.dart';
import 'package:rast/features/chat/threads_notifier.dart';
import 'package:rast/features/discovery/eligibility.dart';
import 'package:rast/features/premium/premium_notifier.dart';
import 'package:rast/features/safety/safety_actions.dart';
import 'package:rast/features/safety/safety_notifier.dart';

import '../helpers/app.dart';

void main() {
  testWidgets('free member sees locked previews; Premium preview reveals ages', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c, initialLocation: '/likes');
    final count = c.read(incomingLikesProvider).length;
    expect(count, greaterThan(1));
    expect(find.text('$count people already like you.'), findsOneWidget);
    expect(find.text('Likes you'), findsWidgets);
    expect(find.text('See who likes you'), findsOneWidget);
    await tester.tap(find.byKey(const Key('locked-like-0')));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/likes/plus');
    expect(find.text('Get rast Plus'), findsOneWidget);
    await tester.tap(find.text('Get rast Plus'));
    await tester.pumpAndSettle();
    expect(c.read(premiumProvider), isTrue);
    expect(currentPath(c), '/likes');
    expect(find.text('They made the first move. Your turn.'), findsOneWidget);
    expect(find.text('Tap a profile to like them back or pass.'), findsOneWidget);
    expect(find.text('Likes you'), findsNothing);
    await finishToasts(tester);
  });

  testWidgets('premium like-back from Likes You opens the match', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    c.read(premiumProvider.notifier).activatePreview();
    await pumpRast(tester, c, initialLocation: '/likes');
    await tester.tap(find.byKey(const Key('like-p1')));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/likes/people/p1');
    expect(find.text('Like back'), findsOneWidget);
    await tester.tap(find.text('Like back'));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/matches/p1');
    expect(find.text('THAT FEELING? MUTUAL.'), findsOneWidget);
    await tester.tap(find.text('Say hello'));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/chats/match-p1');
    expect(find.text('“Shall we start with a hello?”'), findsOneWidget);
  });

  testWidgets('a blocked person is excluded from the incoming count', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    final before = c.read(incomingLikesProvider).length;
    c.read(safetyProvider.notifier).block('p1');
    await pumpRast(tester, c, initialLocation: '/likes');
    expect(c.read(incomingLikesProvider).length, before - 1);
  });

  testWidgets('chats list, unread filter, open and send', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c, initialLocation: '/chats');
    expect(find.byKey(const Key('thread-t1')), findsOneWidget);
    expect(find.byKey(const Key('thread-t2')), findsOneWidget);
    expect(find.text('Maybe we should make the next time a coffee?'), findsOneWidget);
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('thread-t1')), findsOneWidget);
    expect(find.byKey(const Key('thread-t2')), findsNothing);
    await tester.tap(find.byKey(const Key('thread-t1')));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/chats/t1');
    expect(c.read(threadsProvider.notifier).byId('t1')!.unread, 0);
    expect(find.byType(MessageBubble), findsNWidgets(3));
    await tester.enterText(find.byType(TextField), '  hi  ');
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pumpAndSettle();
    expect(find.byType(MessageBubble), findsNWidgets(4));
    expect(c.read(threadsProvider.notifier).byId('t1')!.last!.text, 'hi');
    expect(c.read(threadsProvider.notifier).byId('t1')!.last!.own, isTrue);
  });

  testWidgets('an unknown thread lands on Chats', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c, initialLocation: '/chats/nope');
    expect(currentPath(c), '/chats');
  });

  testWidgets('removing the connection from inside the conversation leaves it for good', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c, initialLocation: '/chats');
    await tester.tap(find.byKey(const Key('thread-t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Conversation options'));
    await tester.pumpAndSettle();
    expect(find.text('Remove connection'), findsOneWidget);
    await tester.tap(find.text('Remove connection'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this connection?'), findsOneWidget);
    await tester.tap(find.widgetWithText(PrimaryButton, 'Remove connection'));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/chats');
    expect(find.byKey(const Key('thread-t1')), findsNothing);
    expect(c.read(safetyProvider).disconnected, contains('p3'));
    // Reopening the old route must not resurrect the thread.
    routerOf(c).push('/chats/t1');
    await tester.pumpAndSettle();
    expect(currentPath(c), '/chats');
    await finishToasts(tester);
  });

  testWidgets('match page for a removed pair falls back to Chats', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    c.read(safetyActionsProvider).removePerson('p1');
    await pumpRast(tester, c, initialLocation: '/matches/p1');
    expect(currentPath(c), '/chats');
  });
}
