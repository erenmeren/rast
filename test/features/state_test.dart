import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/app/providers.dart';
import 'package:rast/core/models/models.dart';
import 'package:rast/core/storage/preferences_store.dart';
import 'package:rast/data/mock/mock_people.dart';
import 'package:rast/features/auth/session_notifier.dart';
import 'package:rast/features/chat/threads_notifier.dart';
import 'package:rast/features/discovery/deck_notifier.dart';
import 'package:rast/features/discovery/eligibility.dart';
import 'package:rast/features/profile/preferences_notifier.dart';
import 'package:rast/features/profile/profile_notifier.dart';
import 'package:rast/features/profile/settings_notifier.dart';
import 'package:rast/features/safety/safety_actions.dart';
import 'package:rast/features/safety/safety_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A member who has finished setup, like the prototype's demo state.
Future<ProviderContainer> activeMember({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    preferencesStoreProvider.overrideWithValue(PreferencesStore(sp)),
    randomProvider.overrideWithValue(Random(1)),
  ]);
  addTearDown(container.dispose);
  final profile = container.read(profileProvider.notifier);
  profile.setBirthDate(DateTime.utc(1998, 5, 14));
  profile.setGender(Gender.woman);
  profile.useSamplePhotos();
  container.read(preferencesProvider.notifier).replace(const Preferences(minAge: 23, maxAge: 36));
  final settings = container.read(settingsProvider.notifier);
  settings.setLocation(true);
  settings.setVisible(true);
  container.read(safetyProvider); // start loading
  await Future<void>.delayed(Duration.zero);
  return container;
}

void main() {
  test('birth date persists as an ISO date and loads back', () async {
    final c = await activeMember();
    final sp = await SharedPreferences.getInstance();
    expect(sp.getString('rast.profile.birthDate'), '1998-05-14');
    expect(sp.getInt('rast.profile.age'), isNull);
    final again = ProviderContainer(overrides: [preferencesStoreProvider.overrideWithValue(PreferencesStore(sp))]);
    addTearDown(again.dispose);
    expect(again.read(profileProvider).birthDate, DateTime.utc(1998, 5, 14));
    c.read(profileProvider.notifier).setBirthDate(null);
    expect(sp.getString('rast.profile.birthDate'), isNull);
  });

  test('deck order is a stable permutation and photo taps keep it', () async {
    final c = await activeMember();
    final order = c.read(deckProvider).order;
    expect(order.toSet(), {'p1', 'p2', 'p3', 'p4', 'p5', 'p6'});
    c.read(deckProvider.notifier).nextPhoto();
    expect(c.read(deckProvider).order, order);
    expect(c.read(deckProvider).photoIndex, 1);
  });

  test('eligibility applies preferences, delay, safety and seen state', () async {
    final c = await activeMember();
    final ids = c.read(eligiblePeopleProvider).map((p) => p.id).toSet();
    // p2 and p3 are matched already (seeded threads).
    expect(ids, {'p1', 'p4', 'p5', 'p6'});

    c.read(preferencesProvider.notifier).replace(const Preferences(interests: {Interest.women}, minAge: 18, maxAge: 99));
    expect(c.read(eligiblePeopleProvider).map((p) => p.id).toSet(), {'p1', 'p5'});

    c.read(preferencesProvider.notifier).replace(const Preferences(minAge: 30, maxAge: 99));
    expect(c.read(eligiblePeopleProvider).map((p) => p.id).toSet(), {'p4', 'p6'});
  });

  test('a longer own delay hides recent crossings', () async {
    final c = await activeMember();
    c.read(settingsProvider.notifier).setDelay(4); // p1 crossed 3h ago
    expect(c.read(eligiblePeopleProvider).any((p) => p.id == 'p1'), isFalse);
    c.read(settingsProvider.notifier).setDelay(24);
    expect(c.read(eligiblePeopleProvider), isEmpty);
  });

  test('pausing visibility or losing a photo empties the deck but not chats', () async {
    final c = await activeMember();
    c.read(settingsProvider.notifier).setVisible(false);
    expect(c.read(eligiblePeopleProvider), isEmpty);
    expect(c.read(visibleThreadsProvider).length, 2);
    c.read(settingsProvider.notifier).setVisible(true);
    c.read(profileProvider.notifier).setPhoto(1, null);
    expect(c.read(eligiblePeopleProvider), isEmpty);
    expect(c.read(discoveryActiveProvider), isFalse);
  });

  test('blocking hides the person from the deck and incoming likes', () async {
    final c = await activeMember();
    expect(c.read(incomingLikesProvider).map((p) => p.id), contains('p1'));
    c.read(safetyProvider.notifier).block('p1');
    expect(c.read(eligiblePeopleProvider).any((p) => p.id == 'p1'), isFalse);
    expect(c.read(incomingLikesProvider).any((p) => p.id == 'p1'), isFalse);
  });

  test('remove connection deletes the thread and is permanent', () async {
    final c = await activeMember();
    expect(c.read(safetyActionsProvider).removePerson('p3'), isTrue);
    expect(c.read(threadsProvider).any((t) => t.personId == 'p3'), isFalse);
    expect(c.read(safetyProvider).disconnected, contains('p3'));
    expect(c.read(safetyProvider).blocked, isNot(contains('p3')));
    c.read(safetyActionsProvider).unblock('p3');
    expect(c.read(safetyProvider).disconnected, contains('p3'));
    expect(c.read(eligiblePeopleProvider).any((p) => p.id == 'p3'), isFalse);
  });

  test('blocking a match removes it permanently; blocking a stranger is reversible', () async {
    final c = await activeMember();
    c.read(safetyActionsProvider).removePerson('p2', block: true);
    expect(c.read(safetyProvider).blocked, contains('p2'));
    expect(c.read(safetyProvider).disconnected, contains('p2'));

    c.read(safetyActionsProvider).removePerson('p4', block: true);
    expect(c.read(safetyProvider).disconnected, isNot(contains('p4')));
    c.read(safetyActionsProvider).unblock('p4');
    expect(c.read(eligiblePeopleProvider).any((p) => p.id == 'p4'), isTrue);
  });

  test('report with and without block', () async {
    final c = await activeMember();
    c.read(safetyActionsProvider).report('p3', 'Scam or spam', alsoBlock: false);
    expect(c.read(threadsProvider).any((t) => t.personId == 'p3'), isTrue);
    expect(c.read(safetyProvider).hasReport('p3'), isTrue);
    c.read(safetyActionsProvider).report('p3', 'Scam or spam', alsoBlock: true);
    expect(c.read(threadsProvider).any((t) => t.personId == 'p3'), isFalse);
    expect(c.read(safetyProvider).blocked, contains('p3'));
    expect(c.read(safetyProvider).disconnected, contains('p3'));
    expect(c.read(safetyProvider).reports.length, 1);
  });

  test('rewind restores only available passes', () async {
    final c = await activeMember();
    final deck = c.read(deckProvider.notifier);
    final first = c.read(currentPersonProvider)!.id;
    deck.pass(first);
    expect(c.read(currentPersonProvider)!.id, isNot(first));
    expect(await deck.rewind(), first);
    expect(c.read(currentPersonProvider)!.id, first);

    deck.pass(first);
    c.read(safetyProvider.notifier).block(first);
    expect(await deck.rewind(), isNull);
    expect(c.read(deckProvider).history, isEmpty);
  });

  test('finishSetup rejects incomplete profiles in order', () async {
    final c = await activeMember();
    final session = c.read(sessionProvider.notifier);
    c.read(profileProvider.notifier).setPhoto(3, null);
    expect(session.finishSetup(locationGranted: true)?.route, '/setup/photos');
    c.read(profileProvider.notifier).useSamplePhotos();
    expect(session.finishSetup(locationGranted: true)?.route, '/auth/phone');
    session.markVerified();
    c.read(profileProvider.notifier).setGender(Gender.self);
    expect(session.finishSetup(locationGranted: true)?.route, '/setup/about');
    c.read(profileProvider.notifier).setCustomGender('Genderfluid');
    expect(session.finishSetup(locationGranted: false), isNull);
    expect(c.read(sessionProvider).phase, SessionPhase.introPending);
    expect(c.read(settingsProvider).locationEnabled, isFalse);
  });

  test('send trims, caps at 1000 and ignores blanks', () async {
    final c = await activeMember();
    final threads = c.read(threadsProvider.notifier);
    expect(threads.send('t2', '   '), isFalse);
    expect(threads.send('t2', '  hi  '), isTrue);
    expect(threads.byId('t2')!.last!.text, 'hi');
    threads.send('t2', 'x' * 1500);
    expect(threads.byId('t2')!.last!.text.length, 1000);
    expect(threads.ensureThread('p1').id, 'match-p1');
    expect(threads.ensureThread('p1').id, threads.byPerson('p1')!.id);
  });

  test('preferences toggle rules', () {
    var p = Preferences.defaults;
    p = p.toggled(Interest.women);
    expect(p.interests, {Interest.women});
    p = p.toggled(Interest.men);
    expect(p.interests, {Interest.women, Interest.men});
    p = p.toggled(Interest.everyone);
    expect(p.interests, {Interest.everyone});
    expect(p.withRange(40, 30).minAge <= p.withRange(40, 30).maxAge, isTrue);
    expect(const Preferences(minAge: 23, maxAge: 36).summary, '23–36 years · Everyone');
    expect(const Preferences(interests: {Interest.men, Interest.women}).summary, '18–99+ years · Women, Men');
  });

  test('safety state survives a relaunch through the store', () async {
    final c = await activeMember();
    c.read(safetyProvider.notifier).block('p5');
    c.read(safetyProvider.notifier).disconnect('p6');
    await Future<void>.delayed(Duration.zero);
    final sp = await SharedPreferences.getInstance();
    final again = ProviderContainer(overrides: [preferencesStoreProvider.overrideWithValue(PreferencesStore(sp))]);
    addTearDown(again.dispose);
    again.read(safetyProvider);
    await Future<void>.delayed(Duration.zero);
    expect(again.read(safetyProvider).blocked, {'p5'});
    expect(again.read(safetyProvider).disconnected, {'p6'});
    expect(samplePhotos.length, 4);
  });
}
