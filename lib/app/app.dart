import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/appearance.dart';
import '../core/theme/rast_theme.dart';
import 'router.dart';

class RastApp extends ConsumerWidget {
  const RastApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final router = ref.watch(routerProvider);
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
