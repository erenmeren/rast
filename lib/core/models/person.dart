import 'package:flutter/painting.dart';

/// Own gender identity. Identity and interests are separate concepts.
enum Gender {
  woman('Woman'),
  man('Man'),
  nonbinary('Non-binary'),
  self('Self-describe');

  const Gender(this.label);
  final String label;
}

/// Who someone would like to meet. Multi-select; [everyone] clears the rest.
enum Interest {
  everyone('Everyone'),
  women('Women'),
  men('Men'),
  nonbinary('Non-binary people');

  const Interest(this.label);
  final String label;

  /// Whether a person with [gender] fits this interest. A self-described
  /// identity currently matches only [everyone]; the handoff explicitly leaves
  /// a finer mapping as an open product decision.
  bool matches(Gender gender) => switch (this) {
        Interest.everyone => true,
        Interest.women => gender == Gender.woman,
        Interest.men => gender == Gender.man,
        Interest.nonbinary => gender == Gender.nonbinary,
      };
}

bool interestsMatch(Set<Interest> interests, Gender gender) =>
    interests.any((i) => i.matches(gender));

/// A fictional person in the mock feed.
class Person {
  const Person({
    required this.id,
    required this.age,
    required this.gender,
    required this.photo,
    required this.delayHours,
    required this.hoursAgo,
    required this.distanceMeters,
    required this.likesYou,
    this.interests = const {Interest.everyone},
    this.minAge = 18,
    this.maxAge = 99,
  });

  final String id;
  final int age;
  final Gender gender;
  final String photo;
  final int delayHours;
  final int hoursAgo;
  final double distanceMeters;
  final bool likesYou;
  final Set<Interest> interests;
  final int minAge;
  final int maxAge;
}

/// One frame of a person's four-photo album.
class PhotoFrame {
  const PhotoFrame(this.src, this.zoom, this.alignment);
  final String src;
  final double zoom;
  final Alignment alignment;
}

const String cityPhoto = 'assets/photos/city.jpg';
String portrait(int n) => 'assets/photos/portrait-$n.jpg';

/// The prototype reuses each portrait with different crops plus a city shot.
List<PhotoFrame> albumOf(Person p) => [
      PhotoFrame(p.photo, 1.0, const Alignment(0, -0.34)),
      PhotoFrame(p.photo, 1.3, const Alignment(0, -0.56)),
      const PhotoFrame(cityPhoto, 1.0, Alignment.center),
      PhotoFrame(p.photo, 1.08, const Alignment(0, -0.04)),
    ];
