import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/models.dart';

class IntroNotifier extends Notifier<IntroStatus> {
  @override
  IntroStatus build() => ref.read(introRepositoryProvider).status();

  void _set(IntroStatus s) {
    state = s;
    ref.read(introRepositoryProvider).set(s);
  }

  void markPending() => _set(IntroStatus.pending);
  void complete() => _set(IntroStatus.complete);
  void reset() => _set(IntroStatus.none);
}

final introProvider = NotifierProvider<IntroNotifier, IntroStatus>(IntroNotifier.new);
