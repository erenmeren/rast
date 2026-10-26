import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../../data/repositories.dart';
import '../discovery/people_directory.dart';

/// Likes You from the server: previews for free members, cards for premium.
/// Null until the first answer; stays null on the mock backend.
class LikesNotifier extends Notifier<LikesYouResult?> {
  Future<void> _ready = Future.value();
  Future<void> get ready => _ready;

  @override
  LikesYouResult? build() {
    if (ref.read(backendKindProvider) != BackendKind.supabase) return null;
    _ready = refresh();
    return null;
  }

  Future<void> refresh() async {
    try {
      final result = await ref.read(discoveryRepositoryProvider).likesYou();
      ref.read(peopleProvider.notifier).add(result.cards);
      state = result;
    } catch (_) {}
  }

  /// The previews as people the locked tiles can render: an opaque token as
  /// the photo source and the age, nothing else.
  static List<Person> previewsAsPeople(LikesYouResult r) => [
        for (final p in r.previews) Person(id: 'preview:${p.token}', age: p.age, gender: null, photo: 'preview:${p.token}', likesYou: true),
      ];
}

final likesProvider = NotifierProvider<LikesNotifier, LikesYouResult?>(LikesNotifier.new);
