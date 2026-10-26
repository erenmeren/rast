import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../core/ui/ui.dart';
import '../../data/repositories.dart';
import '../chat/threads_notifier.dart';
import '../premium/premium_notifier.dart';
import '../../app/providers.dart';
import '../likes/likes_notifier.dart';
import 'deck_notifier.dart';
import 'eligibility.dart';

/// Like [person]. A mutual like creates the connection and opens the match
/// moment; otherwise the member returns to [returnTo] with a toast.
/// Re-checks eligibility first so a stale card cannot like someone who has
/// since become unavailable.
Future<void> likePerson(BuildContext context, WidgetRef ref, Person person, {required String returnTo, bool fromLikes = false}) async {
  final eligible = ref.read(eligiblePeopleProvider).any((p) => p.id == person.id) ||
      ref.read(incomingLikesProvider).any((p) => p.id == person.id);
  if (!eligible || (fromLikes && !ref.read(premiumProvider))) {
    context.go(returnTo);
    showToast(context, 'This profile is no longer available.');
    return;
  }
  final outcome = await ref.read(deckProvider.notifier).like(person.id);
  if (ref.read(backendKindProvider) == BackendKind.supabase) ref.read(likesProvider.notifier).refresh();
  if (!context.mounted) return;
  switch (outcome) {
    case LikeOutcome.matched:
      ref.read(threadsProvider.notifier).ensureThread(person.id);
      context.go('/matches/${person.id}');
    case LikeOutcome.liked:
      if (GoRouterState.of(context).matchedLocation != returnTo) context.go(returnTo);
      showToast(context, 'Like sent. A mutual like starts a conversation.');
    case LikeOutcome.unavailable:
      context.go(returnTo);
      showToast(context, 'This profile is no longer available.');
  }
}

void passPerson(BuildContext context, WidgetRef ref, Person person, {String? returnTo}) {
  ref.read(deckProvider.notifier).pass(person.id);
  if (returnTo != null) context.go(returnTo);
}
