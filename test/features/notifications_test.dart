import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/models/models.dart';
import 'package:rast/core/ui/ui.dart';
import 'package:rast/features/profile/settings_notifier.dart';

import '../helpers/app.dart';

void main() {
  test('each flag persists and reloads', () async {
    final c = await testContainer();
    c.read(settingsProvider.notifier).setNotify(NotifyKind.likes, false);
    expect(c.read(settingsProvider).notifyLikes, isFalse);
    expect(c.read(settingsProvider).notifyMatches, isTrue);
    expect(c.read(settingsProvider).anyNotify, isTrue);
    final again = await testContainer(prefs: {'rast.notify.likes': false, 'rast.notify.messages': false, 'rast.notify.matches': false});
    expect(again.read(settingsProvider).anyNotify, isFalse);
  });

  testWidgets('the sheet shows three toggles and the row reads Off when all are off', (tester) async {
    final c = await testContainer();
    makeActiveMember(c);
    await pumpRast(tester, c, initialLocation: '/profile');
    await tester.ensureVisible(find.text('Notifications'));
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('New matches'), findsOneWidget);
    expect(find.text('Likes'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    for (final s in find.byType(RastSwitch).evaluate().toList()) {
      await tester.tap(find.byWidget(s.widget));
      await tester.pumpAndSettle();
    }
    expect(c.read(settingsProvider).anyNotify, isFalse);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
  });
}
