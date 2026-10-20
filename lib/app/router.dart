import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/models.dart';
import '../features/auth/session_notifier.dart';
import '../features/auth/phone_page.dart';
import '../features/auth/verify_page.dart';
import '../features/auth/welcome_page.dart';
import '../features/onboarding/about_you_page.dart';
import '../features/onboarding/location_permission_page.dart';
import '../features/onboarding/photos_page.dart';
import '../features/onboarding/preferences_page.dart';
import '../features/intro/how_it_works_page.dart';
import '../features/discovery/discover_page.dart';
import '../features/discovery/person_detail_page.dart';
import 'shell.dart';
import 'stub_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Re-evaluates redirects whenever the session phase changes.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    ref.listen<Session>(sessionProvider, (_, _) => notifyListeners());
  }
  final Ref ref;

  static bool _isAuthOrSetup(String path) =>
      path == '/welcome' || path.startsWith('/auth/') || path.startsWith('/setup/');

  String? redirect(BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    final phase = ref.read(sessionProvider).phase;
    switch (phase) {
      case SessionPhase.signedOut:
        return _isAuthOrSetup(path) ? null : '/welcome';
      case SessionPhase.onboarding:
        return _isAuthOrSetup(path) ? null : '/welcome';
      case SessionPhase.introPending:
        return path == '/intro' ? null : '/intro';
      case SessionPhase.active:
        return _isAuthOrSetup(path) || path == '/intro' ? '/discover' : null;
    }
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/discover',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/discover'),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(path: '/auth/phone', builder: (_, _) => const PhonePage()),
      GoRoute(path: '/auth/verify', builder: (_, _) => const VerifyPage()),
      GoRoute(path: '/setup/about', builder: (_, _) => const AboutYouPage()),
      GoRoute(path: '/setup/preferences', builder: (_, _) => const PreferencesPage()),
      GoRoute(path: '/setup/photos', builder: (_, _) => const PhotosPage()),
      GoRoute(path: '/setup/location', builder: (_, _) => const LocationPermissionPage()),
      GoRoute(path: '/intro', builder: (_, _) => const HowItWorksPage(required: true)),
      GoRoute(
        path: '/matches/:personId',
        builder: (_, state) => StubPage('Match ${state.pathParameters['personId']}'),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => RastShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/discover',
              builder: (_, _) => const DiscoverPage(),
              routes: [
                GoRoute(
                  path: 'people/:personId',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, state) => PersonDetailPage(personId: state.pathParameters['personId']!, origin: 'discover'),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/likes',
              builder: (_, _) => const StubPage('Likes You'),
              routes: [
                GoRoute(
                  path: 'people/:personId',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, state) => PersonDetailPage(personId: state.pathParameters['personId']!, origin: 'likes'),
                ),
                GoRoute(
                  path: 'plus',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const StubPage('Plus'),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/chats',
              builder: (_, _) => const StubPage('Chats'),
              routes: [
                GoRoute(
                  path: ':threadId',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, state) => StubPage('Thread ${state.pathParameters['threadId']}'),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const StubPage('Profile'),
              routes: [
                GoRoute(path: 'location', builder: (_, _) => const StubPage('Location & visibility')),
                GoRoute(path: 'photos', builder: (_, _) => const PhotosPage(editing: true)),
                GoRoute(path: 'safety', builder: (_, _) => const StubPage('Safety & account')),
                GoRoute(path: 'how-it-works', builder: (_, _) => const HowItWorksPage(required: false)),
                GoRoute(
                  path: 'plus',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const StubPage('Plus'),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});
