import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rast/app/app.dart';
import 'package:rast/app/providers.dart';
import 'package:rast/app/router.dart';
import 'package:rast/app/shell.dart';
import 'package:rast/core/models/models.dart';
import 'package:rast/core/storage/preferences_store.dart';
import 'package:rast/features/auth/session_notifier.dart';
import 'package:rast/features/intro/intro_notifier.dart';
import 'package:rast/features/profile/preferences_notifier.dart';
import 'package:rast/features/profile/profile_notifier.dart';
import 'package:rast/features/profile/settings_notifier.dart';
import 'package:rast/features/safety/safety_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a container with in-memory preferences and a fixed random seed.
Future<ProviderContainer> testContainer({Map<String, Object> prefs = const {}, int seed = 1, List<Override> extra = const []}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    preferencesStoreProvider.overrideWithValue(PreferencesStore(sp)),
    randomProvider.overrideWithValue(Random(seed)),
    ...extra,
  ]);
  addTearDown(container.dispose);
  return container;
}

/// Puts the container into the "finished setup, intro complete" state.
void makeActiveMember(ProviderContainer c, {bool introComplete = true, bool verified = true}) {
  final profile = c.read(profileProvider.notifier);
  profile.setAge(28);
  profile.setGender(Gender.woman);
  profile.setPhone('+44', '7700 900 123');
  profile.useSamplePhotos();
  c.read(preferencesProvider.notifier).replace(const Preferences(minAge: 23, maxAge: 36));
  final settings = c.read(settingsProvider.notifier);
  settings.setLocation(true);
  settings.setVisible(true);
  if (verified) c.read(sessionProvider.notifier).markVerified();
  if (introComplete) c.read(introProvider.notifier).complete();
  final problem = c.read(sessionProvider.notifier).finishSetup(locationGranted: true);
  assert(problem == null, problem.message);
}

bool _fontLoaded = false;

/// Loads the real Plus Jakarta Sans so layout tests measure real widths
/// instead of the square test glyphs.
Future<void> loadRastFont() async {
  if (_fontLoaded) return;
  final bytes = File('assets/fonts/PlusJakartaSans-Variable.ttf').readAsBytesSync();
  final loader = FontLoader('PlusJakartaSans')..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
  _fontLoaded = true;
}

/// Pumps the real app with [container]. Phone-sized surface.
Future<void> pumpRast(WidgetTester tester, ProviderContainer container, {String? initialLocation, bool settle = true}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await loadRastFont();
  container.read(safetyProvider); // async mock load completes on the next pump
  if (initialLocation != null) {
    container.read(routerProvider).go(initialLocation);
  }
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const RastApp()));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Location of the top-most route, including imperatively pushed ones.
String currentPath(ProviderContainer c) {
  final config = c.read(routerProvider).routerDelegate.currentConfiguration;
  final last = config.last;
  return last.matchedLocation;
}

GoRouter routerOf(ProviderContainer c) => c.read(routerProvider);

/// Taps a bottom-navigation item by its label.
Future<void> tapNav(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(RastBottomNav), matching: find.text(label)));
  await tester.pumpAndSettle();
}
