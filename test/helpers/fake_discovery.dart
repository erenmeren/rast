import 'package:rast/core/models/models.dart';
import 'package:rast/data/repositories.dart';

Person card(String id, {bool likesYou = false}) => Person(
      id: id, age: 30, gender: Gender.woman, photo: 'sb:$id/0.jpg',
      photos: ['sb:$id/0.jpg', 'sb:$id/1.jpg', 'sb:$id/2.jpg', 'sb:$id/3.jpg'], likesYou: likesYou,
      delayHours: 0, hoursAgo: 0, distanceMeters: 0);

/// Scripted server: a fixed deck, one person who likes back.
class FakeDiscovery implements DiscoveryRepository {
  final log = <String>[];
  List<Person> deck = [card('a'), card('b'), card('c')];
  Set<String> likesMe = {'b'};
  Set<String> gone = {};

  @override
  Future<String> startSession() async {
    log.add('session');
    return 's1';
  }

  @override
  Future<CardPage> cards(String sessionId, {String? after}) async => CardPage([for (final p in deck) if (!gone.contains(p.id)) p], null);

  @override
  Future<LikeOutcome> like(String id) async {
    log.add('like $id');
    if (gone.contains(id)) return LikeOutcome.unavailable;
    return likesMe.contains(id) ? LikeOutcome.matched : LikeOutcome.liked;
  }

  @override
  Future<bool> pass(String id) async {
    log.add('pass $id');
    return !gone.contains(id);
  }

  String? lastPass;
  @override
  Future<String?> rewind() async {
    final p = RegExp(r'pass (\w+)').allMatches(log.join(' ')).lastOrNull?.group(1);
    return p != null && !gone.contains(p) ? p : null;
  }

  LikesYouResult likes = const LikesYouResult(premium: false, count: 0, previews: [], cards: []);
  @override
  Future<LikesYouResult> likesYou() async => likes;
  @override
  Future<List<Connection>> connections() async => [];
  @override
  Future<Person?> personCard(String id) async => deck.where((p) => p.id == id).firstOrNull;
}

