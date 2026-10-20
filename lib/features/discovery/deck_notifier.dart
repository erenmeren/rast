import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/rules/rules.dart';
import '../../data/mock/mock_people.dart';
import '../safety/safety_notifier.dart';

/// The Discover session: one shuffled order, what was passed/liked, the pass
/// history for Rewind and the album frame of the current card.
class DeckState {
  const DeckState({
    required this.order,
    this.passed = const {},
    this.liked = const {},
    this.history = const [],
    this.focus,
    this.photoIndex = 0,
  });

  final List<String> order;
  final Set<String> passed;
  final Set<String> liked;
  final List<String> history;
  final String? focus;
  final int photoIndex;

  DeckState copyWith({
    List<String>? order,
    Set<String>? passed,
    Set<String>? liked,
    List<String>? history,
    String? focus,
    bool clearFocus = false,
    int? photoIndex,
  }) =>
      DeckState(
        order: order ?? this.order,
        passed: passed ?? this.passed,
        liked: liked ?? this.liked,
        history: history ?? this.history,
        focus: clearFocus ? null : (focus ?? this.focus),
        photoIndex: photoIndex ?? this.photoIndex,
      );
}

class DeckNotifier extends Notifier<DeckState> {
  @override
  DeckState build() => DeckState(
        order: shuffleIds([for (final p in mockPeople) p.id], random: ref.read(randomProvider)),
      );

  void pass(String id) => state = state.copyWith(
        passed: {...state.passed, id},
        history: [...state.history, id],
        clearFocus: true,
        photoIndex: 0,
      );

  void like(String id) => state = state.copyWith(liked: {...state.liked, id}, clearFocus: true, photoIndex: 0);

  /// Restores the most recent pass that is still available, or returns null.
  String? rewind() {
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
        passed: {...state.passed}..remove(id),
        liked: {...state.liked}..remove(id),
        history: state.history.where((h) => h != id).toList(),
        clearFocus: state.focus == id,
      );

  void reshuffle() => state = build();
}

final deckProvider = NotifierProvider<DeckNotifier, DeckState>(DeckNotifier.new);
