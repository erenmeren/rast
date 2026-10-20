/// Pure product rules for rast. No I/O, no platform calls.
///
/// These mirror `rast-flutter-handoff/prototype/dist/rules.js` and are the
/// client-side reference. In production the server is authoritative for
/// every encounter and reveal decision; this file is used for mock data and
/// for UI validation only.
library;

import 'dart:math';

const int minAge = 18;

/// Prototype plausibility guard for typed ages. Not an agreed product policy.
const int maxPlausibleAge = 130;

const double encounterRadiusMeters = 20;
const int defaultDelayHours = 2;
const int defaultIntervalSeconds = 30;

const List<int> updateIntervalSeconds = [15, 30, 45, 60, 75, 90, 105, 120];
const List<int> revealDelayHours = [0, 1, 2, 4, 6, 12, 18, 24];

/// Fisher–Yates shuffle on a copy. Encounter times are never an input: the
/// user-facing feed must not read as a timeline.
List<T> shuffleIds<T>(List<T> ids, {Random? random}) {
  final rng = random ?? Random();
  final shuffled = List<T>.of(ids);
  for (var i = shuffled.length - 1; i > 0; i -= 1) {
    final j = rng.nextInt(i + 1);
    final tmp = shuffled[i];
    shuffled[i] = shuffled[j];
    shuffled[j] = tmp;
  }
  return shuffled;
}

/// Ages 99 and older display as "99+". The real age is kept for rules.
String ageLabel(int age) => age >= 99 ? '99+' : '$age';

bool isAdultAge(int? age) =>
    age != null && age >= minAge && age <= maxPlausibleAge;

/// A maximum of 99 represents the open-ended "99+" preference.
bool ageInRange(int age, int min, int max) {
  if (age < 0 || min < 0 || max < min) return false;
  return age >= min && (max == 99 || age <= max);
}

int _validDelay(int? hours) =>
    hours != null && revealDelayHours.contains(hours)
        ? hours
        : defaultDelayHours;

/// The longer of both people's privacy delays always applies.
int effectiveDelay(int? a, int? b) => max(_validDelay(a), _validDelay(b));

/// Evaluate a simulated encounter. `distanceMeters` is the distance between
/// the two people's centres, not the sum of their radii.
bool canRevealEncounter({
  required double distanceMeters,
  required DateTime encounterAt,
  required DateTime now,
  required int? delayA,
  required int? delayB,
  required int? ageA,
  required int? ageB,
  required bool visibleA,
  required bool visibleB,
  required bool mutualPreferences,
  bool blocked = false,
  bool disconnected = false,
  required bool accurate,
}) {
  if (distanceMeters.isNaN ||
      distanceMeters < 0 ||
      distanceMeters > encounterRadiusMeters) {
    return false;
  }
  if (!isAdultAge(ageA) || !isAdultAge(ageB)) return false;
  if (!visibleA ||
      !visibleB ||
      !mutualPreferences ||
      !accurate ||
      blocked ||
      disconnected) {
    return false;
  }
  final elapsed = now.difference(encounterAt);
  return elapsed >= Duration(hours: effectiveDelay(delayA, delayB));
}

/// "Immediately", "1 hour", "2 hours", ..., "1 day".
String delayLabel(int hours) {
  if (hours == 0) return 'Immediately';
  if (hours == 24) return '1 day';
  return '$hours ${hours == 1 ? 'hour' : 'hours'}';
}

/// Same as [delayLabel] but "Instant" for zero, as shown on the timing grid.
String delayChipLabel(int hours) => hours == 0 ? 'Instant' : delayLabel(hours);

/// "15 sec", "1 min", "1m 15s", "2 min".
String intervalLabel(int seconds) {
  if (seconds < 60) return '$seconds sec';
  if (seconds % 60 == 0) return '${seconds ~/ 60} min';
  return '${seconds ~/ 60}m ${seconds % 60}s';
}
