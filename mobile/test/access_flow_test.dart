import 'package:battlegraf_mobile/core/router/app_router.dart';
import 'package:battlegraf_mobile/core/theme/app_theme.dart';
import 'package:battlegraf_mobile/presentation/views/login/login_view.dart';
import 'package:battlegraf_mobile/presentation/views/splash/splash_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('App redirect policy', () {
    test('reads a Flutter web hash route without affecting native starts', () {
      expect(
        initialLocationFromBaseUri(
          Uri.parse('http://localhost:5054/#/institution/personas'),
        ),
        '/institution/personas',
      );
      expect(
        initialLocationFromBaseUri(Uri.parse('https://app.example.test/')),
        isNull,
      );
    });

    test('prototype stays public while auth is loading', () {
      expect(
        resolveAppRedirect(
          isLoading: true,
          isAuthenticated: false,
          location: '/battle/demo-bot',
        ),
        isNull,
      );
    });

    test('splash resolves to login or lobby after initialization', () {
      expect(
        resolveAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          location: '/splash',
        ),
        '/login',
      );
      expect(
        resolveAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          location: '/splash',
        ),
        '/lobby',
      );
    });

    test('root waits for bootstrap and then resolves by session', () {
      expect(
        resolveAppRedirect(
          isLoading: true,
          isAuthenticated: false,
          location: '/',
        ),
        isNull,
      );
      expect(
        resolveAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          location: '/',
        ),
        '/login',
      );
      expect(
        resolveAppRedirect(
          isLoading: false,
          isAuthenticated: true,
          location: '/',
        ),
        '/lobby',
      );
    });

    test('protected routes still require authentication', () {
      expect(
        resolveAppRedirect(
          isLoading: false,
          isAuthenticated: false,
          location: '/lobby',
        ),
        '/login',
      );
    });

    test(
      'reload preserves the protected destination while auth initializes',
      () {
        expect(
          resolveAppRedirect(
            isLoading: true,
            isAuthenticated: false,
            location: '/institution/personas',
          ),
          '/splash?from=%2Finstitution%2Fpersonas',
        );
        expect(
          resolveAppRedirect(
            isLoading: false,
            isAuthenticated: true,
            location: '/splash',
            intendedLocation: '/institution/personas',
          ),
          '/institution/personas',
        );
      },
    );
  });

  testWidgets('splash offers direct offline prototype access', (tester) async {
    final router = _accessTestRouter(initialLocation: '/splash');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );

    expect(find.text('ENTRAR AL PROTOTIPO'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('splash-prototype-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('DEMO OFFLINE'), findsOneWidget);
  });

  testWidgets('login scrolls on a small screen and opens bot demo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _accessTestRouter(initialLocation: '/login');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 650));

    expect(find.byKey(const ValueKey('login-scroll-view')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final prototypeButton = find.byKey(
      const ValueKey('login-prototype-button'),
    );
    await tester.drag(
      find.byKey(const ValueKey('login-scroll-view')),
      const Offset(0, -420),
    );
    await tester.pump();
    await tester.tap(prototypeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('DEMO OFFLINE'), findsOneWidget);
  });
}

GoRouter _accessTestRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashView()),
      GoRoute(path: '/login', builder: (context, state) => const LoginView()),
      GoRoute(
        path: '/battle/demo-bot',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('DEMO OFFLINE'))),
      ),
    ],
  );
}
