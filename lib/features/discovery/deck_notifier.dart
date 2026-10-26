import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/rules/rules.dart';
import '../../data/mock/mock_people.dart';
import '../../data/repositories.dart';
import '../safety/safety_notifier.dart';
import 'people_directory.dart';

/// The Discover session: one order, what was passed/liked, the pass history
/// for Rewind and the album frame of the current card. With the mock the
/// order is a local shuffle; with the server it is the session's card order
/// and every action is an RPC.
class DeckState {
  const DeckState({
    required this.order,
    this.passed = const {},
    this.liked = const {},
    this.history = const [],
    this.focus,
    this.photoIndex = 0,
    this.loading = false,
  });

  final List<String> order;
  final Set<String> passed;
  final Set<String> liked;
  final List<String> history;
  final String? focus;
  final int photoIndex;
  final bool loading;

  DeckState copyWith({
    List<String>? order,
    Set<String>? passed,
    Set<String>? liked,
    List<String>? history,
    String? focus,
    bool clearFocus = false,
    int? photoIndex,
    bool? loading,
  }) =>
      DeckState(
        order: order ?? this.order,
        passed: passed ?? this.passed,
        liked: liked ?? this.liked,
        history: history ?? this.history,
        focus: clearFocus ? null : (focus ?? this.focus),
        photoIndex: photoIndex ?? this.photoIndex,
        loading: loading ?? this.loading,
      );
}

class DeckNotifier extends Notifier<DeckState> {
  bool get _server => ref.read(backendKindProvider) == BackendKind.supabase;
  DiscoveryRepository get _repo => ref.read(discoveryRepositoryProvider);
  String? _session;
  Future<void> _ready = Future.value();

  /// Completes when the first server page is in (immediately for the mock).
  Future<void> get ready => _ready;

  @override
  DeckState build() {
    if (!_server) {
      return DeckState(order: shuffleIds([for (final p in mockPeople) p.id], random: ref.read(randomProvider)));
    }
    _ready = _load();
    return const DeckState(order: [], loading: true);
  }

  Future<void> _load() async {
    try {
      _session = await _repo.startSession();
      final cards = <String>[];
      String? after;
      for (var page = 0; page < 5; page++) {
        final result = await _repo.cards(_session!, after: after);
        ref.read(peopleProvider.notifier).add(result.cards);
        cards.addAll(result.cards.map((p) => p.id));
        after = result.next;
        if (after == null) break;
      }
      state = state.copyWith(order: cards, loading: false, clearFocus: true, photoIndex: 0);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  /// A fresh session: new order, new membership.
  Future<void> reload() {
    if (!_server) {
      reshuffle();
      return Future.value();
    }
    state = state.copyWith(loading: true);
    return _ready = _load();
  }

  void _drop(String id) => state = state.copyWith(
        order: state.order.where((o) => o != id).toList(),
        clearFocus: state.focus == id,
        photoIndex: 0,
      );

  Future<LikeOutcome> like(String id) async {
    state = state.copyWith(liked: {...state.liked, id}, clearFocus: true, photoIndex: 0);
    if (!_server) return (personById(id)?.likesYou ?? false) ? LikeOutcome.matched : LikeOutcome.liked;
    final outcome = await _repo.like(id);
    _drop(id);
    return outcome;
  }

  Future<void> pass(String id) async {
    state = state.copyWith(
      passed: {...state.passed, id},
      history: [...state.history, id],
      clearFocus: true,
      photoIndex: 0,
    );
    if (!_server) return;
    await _repo.pass(id);
    _drop(id);
  }

  /// Restores the most recent pass that is still available, or returns null.
  Future<String?> rewind() async {
    if (_server) {
      final id = await _repo.rewind();
      if (id == null) return null;
      state = state.copyWith(
        order: [id, ...state.order.where((o) => o != id)],
        passed: {...state.passed}..remove(id),
        history: state.history.where((h) => h != id).toList(),
        focus: id,
        photoIndex: 0,
      );
      return id;
    }
    final safety = ref.read(safetyProvider.notifier);
    final history = [...state.history];
    String? id;
    while (history.isNotEmpty) {
      final candidate = history.removeLast();
      if (!safety.isUnavailable(candidate)) {
        id = candidate;
        break;
      }
    }
    if (id == null) {
      state = state.copyWith(history: history);
      return null;
    }
    state = state.copyWith(
      history: history,
      passed: {...state.passed}..remove(id),
      focus: id,
      photoIndex: 0,
    );
    return id;
  }

  void focus(String? id) => state = state.copyWith(focus: id, clearFocus: id == null, photoIndex: 0);
  void nextPhoto() => state = state.copyWith(photoIndex: (state.photoIndex + 1) % 4);
  void prevPhoto() => state = state.copyWith(photoIndex: (state.photoIndex + 3) % 4);
  void resetPhoto() => state = state.copyWith(photoIndex: 0, clearFocus: true);

  /// Forget everything about [id] (after a block or removal).
  void forget(String id) => state = state.copyWith(
        order: _server ? state.order.where((o) => o != id).toList() : null,
        passed: {...state.passed}..remove(id),
        liked: {...state.liked}..remove(id),
        history: state.history.where((h) => h != id).toList(),
        clearFocus: state.focus == id,
      );

  void reshuffle() => state = build();
}

final deckProvider = NotifierProvider<DeckNotifier, DeckState>(DeckNotifier.new);
