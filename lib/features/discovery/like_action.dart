import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/ui/ui.dart';
import '../chat/threads_notifier.dart';
import '../premium/premium_notifier.dart';
import 'deck_notifier.dart';
import 'eligibility.dart';

/// Like [person]. A mutual like creates the connection and opens the match
/// moment; otherwise the member returns to [returnTo] with a toast.
/// Re-checks eligibility first so a stale card cannot like someone who has
/// since become unavailable.
void likePerson(BuildContext context, WidgetRef ref, Person person, {required String returnTo, bool fromLikes = false}) {
  final eligible = ref.read(eligiblePeopleProvider).any((p) => p.id == person.id);
  if (!eligible || (fromLikes && !ref.read(premiumProvider))) {
    context.go(returnTo);
    showToast(context, 'This profile is no longer available.');
    return;
  }
  ref.read(deckProvider.notifier).like(person.id);
  if (person.likesYou) {
    ref.read(threadsProvider.notifier).ensureThread(person.id);
    context.go('/matches/${person.id}');
  } else {
    if (GoRouterState.of(context).matchedLocation != returnTo) context.go(returnTo);
    showToast(context, 'Like sent. A mutual like starts a conversation.');
  }
}

void passPerson(BuildContext context, WidgetRef ref, Person person, {String? returnTo}) {
  ref.read(deckProvider.notifier).pass(person.id);
  if (returnTo != null) context.go(returnTo);
}
