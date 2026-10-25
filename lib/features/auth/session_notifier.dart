import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../../core/rules/rules.dart';
import '../chat/threads_notifier.dart';
import '../discovery/deck_notifier.dart';
import '../intro/intro_notifier.dart';
import '../premium/premium_notifier.dart';
import '../profile/preferences_notifier.dart';
import '../profile/profile_notifier.dart';
import '../profile/settings_notifier.dart';
import '../safety/safety_notifier.dart';

/// Where to send the member when setup cannot finish, with the message to show.
class SetupProblem {
  const SetupProblem(this.route, this.message);
  final String route;
  final String message;
}

class SessionNotifier extends Notifier<Session> {
  @override
  Session build() => ref.read(sessionRepositoryProvider).load();

  void _set(Session s) {
    state = s;
    ref.read(sessionRepositoryProvider).save(s);
  }

  /// Welcome → phone. Clears any half-finished member data.
  void startSignup() {
    ref.read(profileProvider.notifier).reset();
    ref.read(preferencesProvider.notifier).reset();
    ref.read(premiumProvider.notifier).end();
    _set(const Session(phase: SessionPhase.onboarding));
  }

  void markVerified() => _set(state.copyWith(verified: true));

  /// Validates every prerequisite in order and either returns the problem or
  /// moves the session on. Both location choices lead to the introduction
  /// if it has never been completed.
  SetupProblem? finishSetup({required bool locationGranted}) {
    final profile = ref.read(profileProvider);
    final prefs = ref.read(preferencesProvider);
    if (!profile.photosComplete) {
      return const SetupProblem('/setup/photos', 'Add all four photos first.');
    }
    if (!state.verified) {
      return SetupProblem(profile.phone.isEmpty ? '/auth/phone' : '/auth/verify', 'Verify your number to finish setup.');
    }
    if (!isAdultAge(profile.age) ||
        profile.gender == null ||
        (profile.gender == Gender.self && profile.customGender.trim().isEmpty)) {
      return const SetupProblem('/setup/about', 'Add your birth date and gender to finish setup.');
    }
    if (!prefs.isValid) {
      return const SetupProblem('/setup/preferences', 'Choose at least one dating preference.');
    }
    final settings = ref.read(settingsProvider.notifier);
    settings.setLocation(locationGranted);
    if (locationGranted) settings.setVisible(true);

    final intro = ref.read(introProvider);
    if (intro != IntroStatus.complete) {
      ref.read(introProvider.notifier).markPending();
      _set(state.copyWith(phase: SessionPhase.introPending));
    } else {
      _set(state.copyWith(phase: SessionPhase.active));
    }
    return null;
  }

  /// Only the story controller calls this, after visible playback completed.
  void completeIntro() {
    if (ref.read(introProvider) != IntroStatus.complete) return;
    _set(state.copyWith(phase: SessionPhase.active));
  }

  void logOut() {
    ref.read(premiumProvider.notifier).end();
    ref.read(profileProvider.notifier).reset();
    ref.read(sessionRepositoryProvider).clear();
    state = Session.signedOut;
  }

  Future<void> deleteAccount() async {
    ref.read(introProvider.notifier).reset();
    await ref.read(safetyProvider.notifier).reset();
    ref.read(premiumProvider.notifier).end();
    ref.read(profileProvider.notifier).reset();
    ref.read(preferencesProvider.notifier).reset();
    await ref.read(settingsProvider.notifier).reset();
    ref.read(threadsProvider.notifier).clearAll();
    ref.read(deckProvider.notifier).reshuffle();
    await ref.read(sessionRepositoryProvider).clear();
    state = Session.signedOut;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Session>(SessionNotifier.new);
