import '../rules/rules.dart';
import 'person.dart';

/// The signed-in member. No name, job, religion or biography by design.
class Profile {
  const Profile({
    this.birthDate,
    this.gender,
    this.customGender = '',
    this.showGender = false,
    this.photos = const [null, null, null, null],
    this.dial = '+44',
    this.phone = '',
  });

  /// UTC calendar date; null until entered.
  final DateTime? birthDate;
  final Gender? gender;
  final String customGender;
  final bool showGender;

  /// Exactly four slots; null means empty.
  final List<String?> photos;
  final String dial;
  final String phone;

  static const empty = Profile();

  /// Age today, derived from the birth date. The production server derives
  /// it from its own clock; this is for the mock and for display.
  int? get age => birthDate == null ? null : ageOn(birthDate!, DateTime.now().toUtc());

  int get photoCount => photos.where((p) => p != null).length;
  bool get photosComplete => photoCount == 4;
  String get primaryPhoto => photos.firstWhere((p) => p != null, orElse: () => portrait(7))!;

  /// What the profile shows under the age, if anything.
  String? get genderDisplay {
    if (!showGender || gender == null) return null;
    return gender == Gender.self ? customGender : gender!.label;
  }

  Profile copyWith({
    DateTime? birthDate,
    bool clearBirthDate = false,
    Gender? gender,
    bool clearGender = false,
    String? customGender,
    bool? showGender,
    List<String?>? photos,
    String? dial,
    String? phone,
  }) {
    return Profile(
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      gender: clearGender ? null : (gender ?? this.gender),
      customGender: customGender ?? this.customGender,
      showGender: showGender ?? this.showGender,
      photos: photos ?? this.photos,
      dial: dial ?? this.dial,
      phone: phone ?? this.phone,
    );
  }
}
