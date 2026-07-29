import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/views/battle/battle_view.dart';
import '../../presentation/views/battle/bot_battle_demo_view.dart';
import '../../presentation/views/battle_lobby/battle_lobby_view.dart';
import '../../presentation/views/login/login_view.dart';
import '../../presentation/views/lobby/lobby_view.dart';
import '../../presentation/views/progression/progression_view.dart';
import '../../presentation/views/splash/splash_view.dart';
import '../../presentation/views/tasks/task_list_view.dart';
import '../../presentation/widgets/retro_ui.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = GoRouterRefreshStream(
    ref.read(authProvider.notifier).stream,
  );

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      return resolveAppRedirect(
        isLoading: authState.isLoading,
        isAuthenticated: authState.isAuthenticated,
        location: state.uri.path,
      );
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashView()),
      GoRoute(path: '/login', builder: (context, state) => const LoginView()),
      GoRoute(path: '/lobby', builder: (context, state) => const LobbyView()),
      GoRoute(
        path: '/battle/demo-bot',
        builder: (context, state) => const BotBattleDemoView(),
      ),
      GoRoute(
        path: '/battle-lobby',
        builder: (context, state) => const BattleLobbyView(),
      ),
      GoRoute(
        path: '/tasks',
        builder: (context, state) => const TaskListView(),
      ),
      GoRoute(
        path: '/progression',
        builder: (context, state) => const ProgressionView(),
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

  ref.onDispose(() {
    router.dispose();
    authRefresh.dispose();
  });
  return router;
});

/// Pure redirect policy kept separate so offline access can be regression-tested.
String? resolveAppRedirect({
  required bool isLoading,
  required bool isAuthenticated,
  required String location,
}) {
  final isLoginRoute = location == '/login';
  final isSplashRoute = location == '/splash';
  final isPrototypeRoute = location == '/battle/demo-bot';

  if (isPrototypeRoute) return null;
  if (isLoading) return isSplashRoute ? null : '/splash';
  if (isSplashRoute) return isAuthenticated ? '/lobby' : '/login';
  if (!isAuthenticated && !isLoginRoute) return '/login';
  if (isAuthenticated && isLoginRoute) return '/lobby';
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

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NO ENCONTRADO')),
      body: const BattleBackdrop(
        child: Center(child: HudLabel('RUTA INVÁLIDA')),
      ),
    );
  }
}
