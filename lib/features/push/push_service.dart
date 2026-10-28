import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/models/models.dart';
import '../../data/repositories.dart';
import '../auth/session_notifier.dart';

/// Registers this install for push while the session is active and opens the
/// right page when the member taps a notification. State: a token has been
/// registered in this session.
class PushService extends Notifier<bool> {
  StreamSubscription<String>? _tokens;
  StreamSubscription<PushTap>? _taps;

  PushRepository get _repo => ref.read(pushRepositoryProvider);

  @override
  bool build() {
    final active = ref.watch(sessionProvider.select((s) => s.phase == SessionPhase.active));
    ref.onDispose(_stop);
    if (active) _start();
    return false;
  }

  Future<void> _start() async {
    if (!await _repo.requestPermission()) return;
    if (!ref.mounted) return;
    _tokens = _repo.tokens().listen((token) async {
      try {
        await _repo.register(token);
        if (ref.mounted) state = true;
      } catch (_) {
        // offline: the next refresh or app start registers again
      }
    });
    _taps = _repo.taps().listen((tap) => ref.read(routerProvider).go(pathFor(tap)));
  }

  void _stop() {
    _tokens?.cancel();
    _tokens = null;
    _taps?.cancel();
    _taps = null;
  }

  /// A like never names the liker, so it opens the list.
  static String pathFor(PushTap tap) => switch (tap.kind) {
        'message' when tap.accountId != null => '/chats/${tap.accountId}',
        'message' || 'matched' => '/chats',
        'liked' => '/likes',
        _ => '/discover',
      };
}

final pushProvider = NotifierProvider<PushService, bool>(PushService.new);
