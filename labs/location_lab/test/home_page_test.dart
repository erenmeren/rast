import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_lab/lab_store.dart';
import 'package:location_lab/main.dart';
import 'package:location_lab/models.dart';
import 'package:location_lab/permissions.dart';
import 'package:location_lab/providers.dart';
import 'package:location_lab/sampler.dart';

import 'memory_store.dart';

class FakeGateway implements PermissionGateway {
  FakeGateway(this.granted);
  final Set<PermissionItem> granted;
  @override
  Future<bool> isGranted(PermissionItem item) async => granted.contains(item);
  @override
  Future<bool> request(PermissionItem item) async {
    granted.add(item);
    return true;
  }
}

Position pos(int tMs) => Position(
      latitude: 41,
      longitude: 29,
      timestamp: DateTime.fromMillisecondsSinceEpoch(tMs, isUtc: true),
      accuracy: 6,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
      isMocked: false,
    );

void main() {
  late LabStore store;
  late Sampler sampler;
  late StreamController<Position> positions;
  var nowMs = 1000000;

  setUp(() async {
    store = MemoryLabStore();
    positions = StreamController<Position>();
    nowMs = 1000000;
    sampler = Sampler(
      store: store,
      positions: (_, _) => positions.stream,
      battery: () async => (77, BatteryStateLabel.discharging),
      now: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newSession: (c) async => LabSession(
        id: 'ui-1',
        deviceId: 'dev',
        deviceModel: 'Test',
        osVersion: 'T',
        appVersion: '0.1.0',
        startedAtUtcMs: 1000000,
        requestedIntervalS: c.intervalS,
        requestedAccuracy: c.accuracy,
      ),
    );
  });
  tearDown(() => store.close());

  Future<void> pump(WidgetTester tester, {Set<PermissionItem>? granted}) async {
    // Phone-tall viewport so the lazily built ListView reaches the event feed.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        labStoreProvider.overrideWith((_) async => store),
        samplerProvider.overrideWith((_) async => sampler),
        permissionFlowProvider.overrideWithValue(
          PermissionFlow(FakeGateway(granted ?? {...PermissionItem.values})),
        ),
      ],
      child: const LabApp(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows interval and accuracy chips and a Start button', (tester) async {
    await pump(tester);
    for (final label in ['15 s', '30 s', '60 s', '120 s', 'Best', 'High', 'Medium']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Fix'), findsNothing);
  });

  testWidgets('Start becomes Stop and live count updates', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Stop'), findsOneWidget);
    positions.add(pos(1000100));
    await tester.pumpAndSettle();
    expect(find.text('Samples: 1'), findsOneWidget);
    expect(find.text('Accuracy: 6 m'), findsOneWidget);
    expect(find.text('Battery: 77%'), findsOneWidget);
  });

  testWidgets('Together marker logs an event', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Together'));
    await tester.pumpAndSettle();
    expect(find.textContaining('marker: together'), findsOneWidget);
  });

  testWidgets('a stream error is shown in red and the fix age keeps ticking', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    positions.add(pos(1000000));
    await tester.pumpAndSettle();
    expect(find.text('Last fix: 0 s ago'), findsOneWidget);

    nowMs += 45000;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Last fix: 45 s ago'), findsOneWidget);

    positions.addError(StateError('location services disabled'));
    await tester.pumpAndSettle();
    final error = tester.widget<Text>(find.textContaining('Stream error:'));
    expect(error.data, contains('location services disabled'));
    expect(error.style?.color, Theme.of(tester.element(find.byType(Scaffold))).colorScheme.error);
  });

  testWidgets('Start is disabled while the sampler is busy', (tester) async {
    final gate = Completer<void>();
    sampler = Sampler(
      store: store,
      positions: (_, _) => positions.stream,
      battery: () async => (77, BatteryStateLabel.discharging),
      now: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newSession: (c) async {
        await gate.future;
        return LabSession(
          id: 'ui-2',
          deviceId: 'dev',
          deviceModel: 'Test',
          osVersion: 'T',
          appVersion: '0.1.0',
          startedAtUtcMs: nowMs,
          requestedIntervalS: c.intervalS,
          requestedAccuracy: c.accuracy,
        );
      },
    );
    await pump(tester);
    await tester.tap(find.text('Start'));
    await tester.pump();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Starting…'));
    expect(button.onPressed, isNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Stop'), findsOneWidget);
    expect((await store.sessions()).length, 1);
  });

  testWidgets('missing permission shows Fix button', (tester) async {
    await pump(tester, granted: {PermissionItem.fineLocation});
    expect(find.text('Fix'), findsOneWidget);
    await tester.tap(find.text('Fix'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fix'));
    await tester.pumpAndSettle();
    expect(find.text('Fix'), findsNothing);
  });
}
