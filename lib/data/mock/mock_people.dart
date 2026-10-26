import '../../core/models/models.dart';

/// Six fictional profiles with stock placeholder portraits.
/// The people pictured are not rast users.
final List<Person> mockPeople = [
  Person(id: 'p1', age: 27, gender: Gender.woman, photo: portrait(1), delayHours: 2, hoursAgo: 3, distanceMeters: 12, likesYou: true),
  Person(id: 'p2', age: 29, gender: Gender.man, photo: portrait(4), delayHours: 1, hoursAgo: 4, distanceMeters: 18, likesYou: false),
  Person(id: 'p3', age: 26, gender: Gender.nonbinary, photo: portrait(6), delayHours: 2, hoursAgo: 5, distanceMeters: 9, likesYou: true),
  Person(id: 'p4', age: 31, gender: Gender.man, photo: portrait(3), delayHours: 2, hoursAgo: 5, distanceMeters: 15, likesYou: false),
  Person(id: 'p5', age: 28, gender: Gender.woman, photo: portrait(2), delayHours: 1, hoursAgo: 6, distanceMeters: 11, likesYou: true),
  Person(id: 'p6', age: 30, gender: Gender.man, photo: portrait(5), delayHours: 2, hoursAgo: 7, distanceMeters: 20, likesYou: true),
];

/// Mock-only lookup; the app goes through the people directory.
Person? personById(String? id) {
  if (id == null) return null;
  for (final p in mockPeople) {
    if (p.id == id) return p;
  }
  return null;
}

/// Sample photos for the member in debug builds.
final List<String?> samplePhotos = [portrait(7), portrait(7), cityPhoto, portrait(7)];

List<Thread> seedThreads() => [
      const Thread(id: 't1', personId: 'p3', unread: 2, messages: [
        Message(text: 'Pretty sure we walked past each other today.', own: false, time: '14:20'),
        Message(text: 'Small city. Good timing.', own: true, time: '14:22'),
        Message(text: 'Maybe we should make the next time a coffee?', own: false, time: '14:24'),
      ]),
      const Thread(id: 't2', personId: 'p2', unread: 0, messages: [
        Message(text: 'Hey! How is your day going?', own: false, time: '12:08'),
        Message(text: 'It just got a little better.', own: true, time: '12:10'),
      ]),
    ];
