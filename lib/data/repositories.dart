import '../core/models/models.dart';

/// Phone verification. Production: SMS provider + session lifecycle.
abstract class AuthRepository {
  Future<void> sendCode(String dial, String phone);
  Future<bool> verify(String code);
  Future<void> signOut();
}

/// Blocks, permanent removals and reports. Production: server-authoritative
/// pair records with idempotent operations.
abstract class SafetyRepository {
  Future<SafetyState> load();
  Future<void> save(SafetyState state);
  Future<void> clear();
}

/// Once-per-account introduction status.
abstract class IntroRepository {
  IntroStatus status();
  Future<void> set(IntroStatus status);
}

/// Premium entitlement. Production: store-verified, server-owned.
abstract class EntitlementRepository {
  bool isPremium();
  Future<void> setPremium(bool value);
}

/// Session phase and the mock member's own data between launches.
abstract class SessionRepository {
  Session load();
  Future<void> save(Session session);
  Future<void> clear();
}

/// The server refused a photo. [reason] is the finalize code: `too_small`,
/// `bad_image`, `missing_upload` or `unknown_photo`.
class PhotoRejected implements Exception {
  const PhotoRejected(this.reason);
  final String reason;
  @override
  String toString() => 'PhotoRejected($reason)';
}

/// How to fetch a remote photo source: the URL plus the headers it needs.
class ImageRequest {
  const ImageRequest(this.uri, {this.headers = const {}});
  final Uri uri;
  final Map<String, String> headers;
}

/// Own photos. Production: upload the original, let the server render the
/// preview and mark the row ready; sources are `sb:<path>` afterwards.
abstract class PhotoRepository {
  /// Returns the source to store in the profile slot.
  Future<String> upload(int slot, String filePath);
  Future<void> remove(String source);

  /// Null for sources the widget can render itself (assets, local files).
  Future<ImageRequest?> resolve(String source);
}

enum LikeOutcome { liked, matched, unavailable }

class CardPage {
  const CardPage(this.cards, this.next);
  final List<Person> cards;
  /// Cursor for the next page; null at the end.
  final String? next;
}

class LikePreview {
  const LikePreview(this.token, this.age);
  final String token;
  final int age;
}

class LikesYouResult {
  const LikesYouResult({required this.premium, required this.count, required this.previews, required this.cards});
  final bool premium;
  final int count;
  final List<LikePreview> previews;
  final List<Person> cards;
}

class Connection {
  const Connection({required this.pairId, required this.revision, required this.person});
  final String pairId;
  final int revision;
  final Person person;
}

/// The Discover deck and everything that shows another member. Production:
/// server sessions with a stable random order; every gate is applied there.
abstract class DiscoveryRepository {
  Future<String> startSession();
  Future<CardPage> cards(String sessionId, {String? after});
  Future<LikeOutcome> like(String id);
  /// False when the person is no longer available.
  Future<bool> pass(String id);
  /// The restored person, or null when nothing could be restored.
  Future<String?> rewind();
  Future<LikesYouResult> likesYou();
  Future<List<Connection>> connections();
  Future<Person?> personCard(String id);
}

/// Conversations. Production: one thread per open match, keyed by the other
/// person's id; messages through the send_message RPC; `changes` fires on
/// every pair event the server publishes for the member.
abstract class ChatRepository {
  Future<List<Thread>> load();
  /// The server sequence number, or null when the pair is closed.
  Future<int?> send(String targetId, String clientOpId, String body);
  Stream<void> changes();
  Future<void> markRead(String threadId);
}

/// Reveal delay, sampling interval and visibility live on the server;
/// notifications and the location flag stay on the device.
abstract class SettingsRepository {
  Settings load();
  Future<void> setDelay(int hours);
  Future<void> setInterval(int seconds);
  Future<void> setVisible(bool value);
  Future<void> setLocation(bool value);
  Future<void> setNotifications(bool value);
  Future<void> clear();
}

/// Pulls the signed-in member's server state into the local store so the
/// synchronous notifiers see it. The mock has nothing to pull.
abstract class BackendSync {
  Future<void> hydrate();
}

abstract class ProfileRepository {
  Profile load();
  Future<void> save(Profile profile);
  Preferences loadPreferences();
  Future<void> savePreferences(Preferences preferences);
  Future<void> clear();
}
