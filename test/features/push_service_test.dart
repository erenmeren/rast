import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/app/providers.dart';
import 'package:rast/app/router.dart';
import 'package:rast/data/repositories.dart';
import 'package:rast/features/auth/session_notifier.dart';
import 'package:rast/features/push/push_service.dart';

import '../helpers/app.dart';
import '../helpers/fake_push.dart';

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  Future<(ProviderContainer, FakePush)> running({bool active = true}) async {
    final fake = FakePush();
    final c = await testContainer(extra: [pushRepositoryProvider.overrideWithValue(fake)]);
    if (active) makeActiveMember(c);
    c.listen(pushProvider, (_, _) {});
    await tick();
    return (c, fake);
  }

  test('an active member registers the first and every refreshed token', () async {
    final (c, fake) = await running();
    expect(fake.permissionRequests, 1);
    fake.tokenController.add('t1');
    fake.tokenController.add('t2');
    await tick();
    expect(fake.registered, ['t1', 't2']);
    expect(c.read(pushProvider), isTrue);
  });

  test('nothing happens while signed out', () async {
    final (_, fake) = await running(active: false);
    expect(fake.permissionRequests, 0);
  });

  test('a tap routes by kind', () async {
    final (c, fake) = await running();
    fake.tapController.add(const PushTap(kind: 'message', accountId: 'p-9'));
    await tick();
    expect(c.read(routerProvider).routeInformationProvider.value.uri.path, '/chats/p-9');
    fake.tapController.add(const PushTap(kind: 'liked'));
    await tick();
    expect(c.read(routerProvider).routeInformationProvider.value.uri.path, '/likes');
  });

  test('a liked tap opens Likes You even with an account id', () {
    expect(PushService.pathFor(const PushTap(kind: 'liked', accountId: 'p-1')), '/likes');
    expect(PushService.pathFor(const PushTap(kind: 'matched', accountId: 'p-1')), '/chats');
    expect(PushService.pathFor(const PushTap(kind: 'message')), '/chats');
    expect(PushService.pathFor(const PushTap(kind: 'other')), '/discover');
  });

  test('log out unregisters before the session ends', () async {
    final (c, fake) = await running();
    await c.read(sessionProvider.notifier).logOut();
    expect(fake.unregistered, isTrue);
  });
}
