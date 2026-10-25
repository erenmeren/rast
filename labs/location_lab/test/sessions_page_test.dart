import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_lab/models.dart';
import 'package:location_lab/providers.dart';
import 'package:location_lab/sessions_page.dart';

import 'memory_store.dart';

LabSession session(String id, {int? ended}) => LabSession(
      id: id,
      deviceId: 'dev',
      deviceModel: 'Test',
      osVersion: 'T',
      appVersion: '0.1.0',
      startedAtUtcMs: 1000000,
      endedAtUtcMs: ended,
      requestedIntervalS: 30,
      requestedAccuracy: RequestedAccuracy.high,
    );

void main() {
  testWidgets('a running session offers Export but not Delete', (tester) async {
    final store = MemoryLabStore();
    await store.insertSession(session('open-1'));
    await store.insertSession(session('done-1', ended: 1600000));
    await tester.pumpWidget(ProviderScope(
      overrides: [labStoreProvider.overrideWith((_) async => store)],
      child: const MaterialApp(home: SessionsPage()),
    ));
    await tester.pumpAndSettle();

    Finder menuOf(String subtitlePart) => find.descendant(
          of: find.ancestor(of: find.textContaining(subtitlePart), matching: find.byType(ListTile)),
          matching: find.byType(PopupMenuButton<String>),
        );

    await tester.tap(menuOf('open ·'));
    await tester.pumpAndSettle();
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.tap(menuOf('10 min ·'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsOneWidget);
  });
}
