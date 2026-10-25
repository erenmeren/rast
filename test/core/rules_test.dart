import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/rules/rules.dart';

bool reveal({
  double distanceMeters = 20,
  DateTime? encounterAt,
  DateTime? now,
  int? delayA = 0,
  int? delayB = 2,
  int? ageA = 24,
  int? ageB = 28,
  bool visibleA = true,
  bool visibleB = true,
  bool mutualPreferences = true,
  bool blocked = false,
  bool disconnected = false,
  bool accurate = true,
}) {
  return canRevealEncounter(
    distanceMeters: distanceMeters,
    encounterAt: encounterAt ?? DateTime.utc(2026, 10, 17, 10),
    now: now ?? DateTime.utc(2026, 10, 17, 12),
    delayA: delayA,
    delayB: delayB,
    ageA: ageA,
    ageB: ageB,
    visibleA: visibleA,
    visibleB: visibleB,
    mutualPreferences: mutualPreferences,
    blocked: blocked,
    disconnected: disconnected,
    accurate: accurate,
  );
}

void main() {
  test('constants match the handoff', () {
    expect(updateIntervalSeconds, [15, 30, 45, 60, 75, 90, 105, 120]);
    expect(revealDelayHours, [0, 1, 2, 4, 6, 12, 18, 24]);
    expect(defaultDelayHours, 2);
    expect(defaultIntervalSeconds, 30);
    expect(encounterRadiusMeters, 20);
  });

  test('99+ is a display and range boundary', () {
    expect(ageLabel(98), '98');
    expect(ageLabel(99), '99+');
  });

  test('ageOn counts completed years, birthday inclusive, leap day on 1 March', () {
    final today = DateTime.utc(2026, 10, 25);
    expect(ageOn(DateTime.utc(1998, 5, 14), today), 28);
    expect(ageOn(DateTime.utc(1998, 10, 25), today), 28);
    expect(ageOn(DateTime.utc(1998, 10, 26), today), 27);
    expect(ageOn(DateTime.utc(2008, 2, 29), DateTime.utc(2026, 2, 28)), 17);
    expect(ageOn(DateTime.utc(2008, 2, 29), DateTime.utc(2026, 3, 1)), 18);
    expect(ageLabel(105), '99+');
    expect(ageInRange(105, 18, 99), isTrue);
    expect(ageInRange(99, 18, 98), isFalse);
    expect(ageInRange(17, 18, 99), isFalse);
    expect(ageInRange(30, 40, 20), isFalse);
    expect(isAdultAge(17), isFalse);
    expect(isAdultAge(18), isTrue);
    expect(isAdultAge(130), isTrue);
    expect(isAdultAge(131), isFalse);
    expect(isAdultAge(null), isFalse);
  });

  test('longer delay wins, invalid falls back to 2', () {
    expect(effectiveDelay(0, 2), 2);
    expect(effectiveDelay(1, 0), 1);
    expect(effectiveDelay(0, 0), 0);
    expect(effectiveDelay(null, 0), 2);
    expect(effectiveDelay(-1, 0), 2);
    for (final a in revealDelayHours) {
      for (final b in revealDelayHours) {
        expect(effectiveDelay(a, b), max(a, b), reason: '$a, $b');
      }
    }
    for (final bad in [3, 5, 23, 25]) {
      expect(effectiveDelay(bad, 0), 2, reason: '$bad');
    }
  });

  test('encounter needs <=20 m and the full mutual delay', () {
    expect(reveal(), isTrue);
    expect(reveal(distanceMeters: 40), isFalse);
    expect(reveal(distanceMeters: 20.001), isFalse);
    expect(reveal(distanceMeters: -1), isFalse);
    expect(reveal(distanceMeters: double.nan), isFalse);
    expect(reveal(now: DateTime.utc(2026, 10, 17, 11, 59, 59, 999)), isFalse);
    expect(reveal(delayB: 0, now: DateTime.utc(2026, 10, 17, 10)), isTrue);
    expect(
      reveal(delayB: 0, now: DateTime.utc(2026, 10, 17, 9, 59, 59, 999)),
      isFalse,
    );
    expect(
      reveal(delayA: 0, delayB: 24, now: DateTime.utc(2026, 10, 18, 9, 59, 59, 999)),
      isFalse,
    );
    expect(reveal(delayA: 0, delayB: 24, now: DateTime.utc(2026, 10, 18, 10)), isTrue);
    expect(reveal(delayA: 24, delayB: 0, now: DateTime.utc(2026, 10, 18, 10)), isTrue);
  });

  test('all gates apply', () {
    final cases = <String, bool Function()>{
      'ageA 17': () => reveal(ageA: 17),
      'ageB 17': () => reveal(ageB: 17),
      'ageA 131': () => reveal(ageA: 131),
      'ageB null': () => reveal(ageB: null),
      'visibleA': () => reveal(visibleA: false),
      'visibleB': () => reveal(visibleB: false),
      'mutual': () => reveal(mutualPreferences: false),
      'blocked': () => reveal(blocked: true),
      'disconnected': () => reveal(disconnected: true),
      'accurate': () => reveal(accurate: false),
    };
    for (final entry in cases.entries) {
      expect(entry.value(), isFalse, reason: entry.key);
    }
    expect(reveal(ageA: 105), isTrue);
  });

  test('shuffle keeps every id once and never mutates', () {
    const ids = ['e-90', 'e-10', 'e-70', 'e-20'];
    final out = shuffleIds(ids, random: Random(7));
    expect([...out]..sort(), [...ids]..sort());
    expect(out.toSet().length, ids.length);
    expect(ids, ['e-90', 'e-10', 'e-70', 'e-20']);
    expect(shuffleIds(<String>[]), isEmpty);
    expect(shuffleIds(['only']), ['only']);
    // Some seed must produce a non-chronological order.
    final anyMoved = List.generate(20, (i) => shuffleIds(ids, random: Random(i)))
        .any((o) => o.join() != ids.join());
    expect(anyMoved, isTrue);
  });

  test('labels', () {
    expect(delayLabel(0), 'Immediately');
    expect(delayLabel(1), '1 hour');
    expect(delayLabel(2), '2 hours');
    expect(delayLabel(24), '1 day');
    expect(delayChipLabel(0), 'Instant');
    expect(delayChipLabel(4), '4 hours');
    expect(intervalLabel(15), '15 sec');
    expect(intervalLabel(60), '1 min');
    expect(intervalLabel(75), '1m 15s');
    expect(intervalLabel(120), '2 min');
  });
}
