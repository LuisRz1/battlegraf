import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/views/battle/bot_battle_demo_view.dart';
import '../../presentation/views/login/login_view.dart';
import '../../presentation/views/lobby/lobby_view.dart';
import '../../presentation/views/splash/splash_view.dart';
import '../../presentation/views/auth/register_view.dart';
import '../../presentation/views/academics/academic_overview_view.dart';
import '../../features/institution/presentation/views/institution_hub_view.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = GoRouterRefreshStream(
    ref.read(authProvider.notifier).stream,
  );
  final browserInitialLocation = initialLocationFromBaseUri(Uri.base);

  final router = GoRouter(
    initialLocation: browserInitialLocation,
    overridePlatformDefaultLocation: browserInitialLocation != null,
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      return resolveAppRedirect(
        isLoading: authState.isLoading,
        isAuthenticated: authState.isAuthenticated,
        location: state.uri.path,
        intendedLocation:
            state.uri.queryParameters['from'] ?? browserInitialLocation,
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashView()),
      GoRoute(path: '/splash', builder: (context, state) => const SplashView()),
      GoRoute(path: '/login', builder: (context, state) => const LoginView()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterView(),
      ),
      GoRoute(path: '/lobby', builder: (context, state) => const LobbyView()),
      GoRoute(
        path: '/academics',
        builder: (context, state) => const AcademicOverviewView(),
      ),
      GoRoute(
        path: '/institution/:area',
        builder: (context, state) => InstitutionHubView(
          area: InstitutionArea.parse(state.pathParameters['area']),
        ),
      ),
      GoRoute(
        path: '/battle/demo-bot',
        builder: (context, state) => const BotBattleDemoView(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    authRefresh.dispose();
  });
  return router;
});

/// Flutter web stores the route after `#`; native deep links remain managed by
/// the platform router because they normally have no fragment.
String? initialLocationFromBaseUri(Uri baseUri) {
  final fragment = Uri.decodeComponent(baseUri.fragment).trim();
  return fragment.startsWith('/') ? fragment : null;
}

/// Pure redirect policy kept separate so offline access can be regression-tested.
String? resolveAppRedirect({
  required bool isLoading,
  required bool isAuthenticated,
  required String location,
  String? intendedLocation,
}) {
  final isLoginRoute = location == '/login';
  final isRegisterRoute = location == '/register';
  final isSplashRoute = location == '/splash';
  final isRootRoute = location == '/';
  final isPrototypeRoute = location == '/battle/demo-bot';
  final safeIntended =
      intendedLocation != null &&
          intendedLocation.startsWith('/') &&
          intendedLocation != '/' &&
          intendedLocation != '/splash' &&
          intendedLocation != '/login'
      ? intendedLocation
      : null;

  if (isPrototypeRoute) return null;
  if (isLoading) {
    return isSplashRoute || isRootRoute
        ? null
        : Uri(path: '/splash', queryParameters: {'from': location}).toString();
  }
  if (isRootRoute) return isAuthenticated ? '/lobby' : '/login';
  if (isSplashRoute) {
    if (isAuthenticated) return safeIntended ?? '/lobby';
    return safeIntended == null
        ? '/login'
        : Uri(
            path: '/login',
            queryParameters: {'from': safeIntended},
          ).toString();
  }
  if (!isAuthenticated && !isLoginRoute && !isRegisterRoute) return '/login';
  if (isAuthenticated && (isLoginRoute || isRegisterRoute)) {
    return safeIntended ?? '/lobby';
  }
  return null;
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
