import '../rules/rules.dart';
import 'person.dart';

/// Dating preferences: interests and one 18–99+ age range.
class Preferences {
  const Preferences({
    this.interests = const {Interest.everyone},
    this.minAge = 18,
    this.maxAge = 99,
  });

  final Set<Interest> interests;
  final int minAge;
  final int maxAge;

  static const defaults = Preferences();

  Preferences copyWith({Set<Interest>? interests, int? minAge, int? maxAge}) =>
      Preferences(
        interests: interests ?? this.interests,
        minAge: minAge ?? this.minAge,
        maxAge: maxAge ?? this.maxAge,
      );

  /// Everyone clears specific picks; a specific pick clears Everyone.
  Preferences toggled(Interest interest) {
    if (interest == Interest.everyone) {
      return copyWith(interests: {Interest.everyone});
    }
    final next = Set<Interest>.of(interests)..remove(Interest.everyone);
    if (next.contains(interest)) {
      next.remove(interest);
    } else {
      next.add(interest);
    }
    return copyWith(interests: next);
  }

  Preferences withRange(int min, int max) {
    final lo = min.clamp(18, 99);
    final hi = max.clamp(18, 99);
    return copyWith(minAge: lo <= hi ? lo : hi, maxAge: hi >= lo ? hi : lo);
  }

  bool get isValid => interests.isNotEmpty;

  /// "23–36 years · Everyone" / "18–99+ years · Women, Men"
  String get summary {
    final who = interests.contains(Interest.everyone)
        ? 'Everyone'
        : Interest.values.where(interests.contains).map((i) => i.label).join(', ');
    return '$minAge–${ageLabel(maxAge)} years · $who';
  }
}
