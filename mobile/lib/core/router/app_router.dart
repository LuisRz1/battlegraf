import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/views/battle/battle_view.dart';
import '../../presentation/views/battle_lobby/battle_lobby_view.dart';
import '../../presentation/views/login/login_view.dart';
import '../../presentation/views/lobby/lobby_view.dart';
import '../../presentation/views/splash/splash_view.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(ref.read(authProvider.notifier).stream),
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login';
      final isSplashRoute = state.matchedLocation == '/splash';

      if (isSplashRoute) return null;

      if (!isAuthenticated && !isLoginRoute) {
        return '/login';
      }

      if (isAuthenticated && (isLoginRoute || isSplashRoute)) {
        return '/lobby';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashView(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: '/lobby',
        builder: (context, state) => const LobbyView(),
      ),
      GoRoute(
        path: '/battle-lobby',
        builder: (context, state) => const BattleLobbyView(),
      ),
      GoRoute(
        path: '/battle/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null || id.isEmpty) return const _NotFoundView();
          return BattleView(battleId: id);
        },
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    stream.listen((_) => notifyListeners());
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NO ENCONTRADO')),
      body: const Center(child: Text('Ruta invalida')),
    );
  }
}
