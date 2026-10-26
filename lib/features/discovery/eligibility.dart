import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../../core/rules/rules.dart';
import '../chat/threads_notifier.dart';
import '../profile/preferences_notifier.dart';
import '../profile/profile_notifier.dart';
import '../profile/settings_notifier.dart';
import '../safety/safety_notifier.dart';
import 'deck_notifier.dart';
import 'people_directory.dart';

/// Whether the member is currently discoverable at all.
final discoveryActiveProvider = Provider<bool>((ref) {
  final s = ref.watch(settingsProvider);
  final p = ref.watch(profileProvider);
  return s.visible && s.locationEnabled && p.photosComplete;
});

/// Everyone who passes every gate right now, in deck order, including people
/// the member already acted on. Mirrors `eligiblePeople(true)` in the prototype.
/// With the server backend the deck is already gated; this is its card list.
final eligibleIncludingSeenProvider = Provider<List<Person>>((ref) {
  final deck = ref.watch(deckProvider);
  final people = ref.watch(peopleProvider);
  if (ref.watch(backendKindProvider) == BackendKind.supabase) {
    return [for (final id in deck.order) ?people[id]];
  }
  final settings = ref.watch(settingsProvider);
  final profile = ref.watch(profileProvider);
  final prefs = ref.watch(preferencesProvider);
  final safety = ref.watch(safetyProvider);
  final sampleTime = ref.watch(sampleTimeProvider);
  final now = ref.watch(clockProvider)();
  final visibleA = ref.watch(discoveryActiveProvider);
  final myGender = profile.gender;
  return [
    for (final id in deck.order)
      if (people[id] case final p?)
        if (canRevealEncounter(
          distanceMeters: p.distanceMeters,
          encounterAt: sampleTime.subtract(Duration(hours: p.hoursAgo)),
          now: now,
          delayA: settings.delayHours,
          delayB: p.delayHours,
          ageA: profile.age,
          ageB: p.age,
          visibleA: visibleA,
          visibleB: true,
          mutualPreferences: ageInRange(p.age, prefs.minAge, prefs.maxAge) &&
              p.gender != null &&
              interestsMatch(prefs.interests, p.gender!) &&
              profile.age != null &&
              ageInRange(profile.age!, p.minAge, p.maxAge) &&
              myGender != null &&
              interestsMatch(p.interests, myGender),
          blocked: safety.blocked.contains(p.id),
          disconnected: safety.disconnected.contains(p.id),
          accurate: true, // provisional: the mock has no real readings
        ))
          p,
  ];
});

/// The Discover deck: eligible people not yet passed, liked or matched.
final eligiblePeopleProvider = Provider<List<Person>>((ref) {
  final deck = ref.watch(deckProvider);
  final threads = ref.watch(threadsProvider);
  return [
    for (final p in ref.watch(eligibleIncludingSeenProvider))
      if (!deck.passed.contains(p.id) && !deck.liked.contains(p.id) && !threads.any((t) => t.personId == p.id)) p,
  ];
});

final incomingLikesProvider = Provider<List<Person>>(
  (ref) => [for (final p in ref.watch(eligiblePeopleProvider)) if (p.likesYou) p],
);

/// The card on top of the deck: the focused person if still eligible, else the first.
final currentPersonProvider = Provider<Person?>((ref) {
  final people = ref.watch(eligiblePeopleProvider);
  final focus = ref.watch(deckProvider).focus;
  for (final p in people) {
    if (p.id == focus) return p;
  }
  return people.isEmpty ? null : people.first;
});

/// Threads whose person is still available.
final visibleThreadsProvider = Provider<List<Thread>>((ref) {
  final safety = ref.watch(safetyProvider);
  final people = ref.watch(peopleProvider);
  return [for (final t in ref.watch(threadsProvider)) if (people.containsKey(t.personId) && !safety.isUnavailable(t.personId)) t];
});

final hasUnreadProvider = Provider<bool>((ref) => ref.watch(visibleThreadsProvider).any((t) => t.unread > 0));

bool isPersonEligible(Ref ref, String id) => ref.read(eligiblePeopleProvider).any((p) => p.id == id);
