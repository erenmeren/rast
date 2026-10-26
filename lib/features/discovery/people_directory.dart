import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../../data/mock/mock_people.dart';

/// Everyone the app currently knows by id: the mock list, or the server
/// cards seen so far (deck, Likes You, connections). Screens look people up
/// here instead of holding card copies.
class PeopleDirectory extends Notifier<Map<String, Person>> {
  @override
  Map<String, Person> build() =>
      ref.read(backendKindProvider) == BackendKind.mock ? {for (final p in mockPeople) p.id: p} : {};

  void add(Iterable<Person> people) {
    if (people.isEmpty) return;
    state = {...state, for (final p in people) p.id: p};
  }

  void forget(String id) => state = {...state}..remove(id);

  Person? byId(String? id) => id == null ? null : state[id];
  bool knows(String? id) => id != null && state.containsKey(id);
}

final peopleProvider = NotifierProvider<PeopleDirectory, Map<String, Person>>(PeopleDirectory.new);

extension PersonLookupRef on Ref {
  Person? person(String? id) => read(peopleProvider.notifier).byId(id);
  bool knowsPerson(String? id) => read(peopleProvider.notifier).knows(id);
}

extension PersonLookupWidgetRef on WidgetRef {
  /// Rebuilds when the directory changes.
  Person? person(String? id) => id == null ? null : watch(peopleProvider)[id];
  bool knowsPerson(String? id) => id != null && watch(peopleProvider).containsKey(id);
}
