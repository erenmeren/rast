import 'package:flutter_test/flutter_test.dart';
import 'package:rast/app/shell.dart';
import 'package:rast/core/models/models.dart';
import 'package:rast/features/auth/session_notifier.dart';
import 'package:rast/features/intro/intro_notifier.dart';

import '../helpers/app.dart';

void main() {
  testWidgets('signed out starts at Welcome', (tester) async {
    final c = await testContainer();
    await pumpRast(tester, c);
    expect(currentPath(c), '/welcome');
    expect(find.byType(RastBottomNav), findsNothing);
  });

  testWidgets('active member sees Discover with four tabs in order', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c);
    expect(currentPath(c), '/discover');
    expect(find.byType(RastBottomNav), findsOneWidget);
    expect(navItems.map((n) => n.label).toList(), ['Discover', 'Likes You', 'Chats', 'Profile']);
    await tapNav(tester, 'Chats');
    expect(currentPath(c), '/chats');
    await tapNav(tester, 'Profile');
    expect(currentPath(c), '/profile');
  });

  testWidgets('pending intro traps every route', (tester) async {
    final c = await testContainer();
    makeActiveMember(c, introComplete: false);
    expect(c.read(sessionProvider).phase, SessionPhase.introPending);
    await pumpRast(tester, c, initialLocation: '/discover');
    expect(currentPath(c), '/intro');
    routerOf(c).go('/chats');
    await tester.pumpAndSettle();
    expect(currentPath(c), '/intro');
    c.read(introProvider.notifier).complete();
    c.read(sessionProvider.notifier).completeIntro();
    await tester.pumpAndSettle();
    expect(currentPath(c), '/discover');
  });

  testWidgets('active member cannot go back to auth routes', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c);
    routerOf(c).go('/welcome');
    await tester.pumpAndSettle();
    expect(currentPath(c), '/discover');
  });

  testWidgets('log out returns to Welcome', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c);
    c.read(sessionProvider.notifier).logOut();
    await tester.pumpAndSettle();
    expect(currentPath(c), '/welcome');
  });
}
