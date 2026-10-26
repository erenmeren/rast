import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/appearance.dart';
import '../core/theme/rast_theme.dart';
import '../features/auth/session_notifier.dart';
import '../features/chat/threads_notifier.dart';
import '../features/discovery/deck_notifier.dart';
import '../features/profile/preferences_notifier.dart';
import '../features/profile/profile_notifier.dart';
import '../features/likes/likes_notifier.dart';
import '../features/location/location_service.dart';
import 'providers.dart';
import 'router.dart';

class RastApp extends ConsumerStatefulWidget {
  const RastApp({super.key});

  @override
  ConsumerState<RastApp> createState() => _RastAppState();
}

class _RastAppState extends ConsumerState<RastApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// What may have changed while the app was in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (ref.read(backendKindProvider) != BackendKind.supabase) return;
    if (!ref.read(sessionProvider).verified) return;
    ref.read(threadsProvider.notifier).refresh();
    ref.read(likesProvider.notifier).refresh();
    // a released encounter shows up without a restart
    if (ref.read(deckProvider).order.isEmpty) ref.read(deckProvider.notifier).reload();
    ref.read(locationProvider.notifier).flush();
    // a save that failed offline is sent again from the store
    final profiles = ref.read(profileRepositoryProvider);
    profiles.save(ref.read(profileProvider)).catchError((Object _) {});
    profiles.savePreferences(ref.read(preferencesProvider)).catchError((Object _) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    final router = ref.watch(routerProvider);
    ref.watch(locationProvider); // keeps the sampler alive for the app's lifetime
    return MaterialApp.router(
      title: 'rast',
      debugShowCheckedModeBanner: false,
      theme: rastTheme(Brightness.light),
      darkTheme: rastTheme(Brightness.dark),
      themeMode: themeModeOf(appearance),
      routerConfig: router,
    );
  }
}
