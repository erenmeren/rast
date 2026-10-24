import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_page.dart';
import 'models.dart';
import 'providers.dart';
import 'sampler.dart';
import 'sessions_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LabApp()));
}

class LabApp extends StatelessWidget {
  const LabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rast location lab',
      theme: ThemeData(colorSchemeSeed: const Color(0xFFFA634F), useMaterial3: true),
      routes: {
        '/': (_) => const _LifecycleBridge(child: HomePage()),
        '/sessions': (_) => const SessionsPage(),
      },
    );
  }
}

/// Forwards app lifecycle changes to the sampler and resumes an open session
/// once the store is ready.
class _LifecycleBridge extends ConsumerStatefulWidget {
  const _LifecycleBridge({required this.child});

  final Widget child;

  @override
  ConsumerState<_LifecycleBridge> createState() => _LifecycleBridgeState();
}

class _LifecycleBridgeState extends ConsumerState<_LifecycleBridge>
    with WidgetsBindingObserver {
  Sampler? _sampler;
  bool _resumed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _sampler?.onLifecycle(switch (state) {
      AppLifecycleState.resumed => Lifecycle.resumed,
      AppLifecycleState.inactive => Lifecycle.inactive,
      AppLifecycleState.paused => Lifecycle.paused,
      AppLifecycleState.hidden => Lifecycle.hidden,
      AppLifecycleState.detached => Lifecycle.detached,
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(samplerProvider, (_, next) {
      final sampler = next.value;
      if (sampler == null || _resumed) return;
      _sampler = sampler;
      _resumed = true;
      sampler.resumeIfOpen();
    });
    return widget.child;
  }
}
