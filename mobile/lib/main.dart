import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/mobile_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (MobileConfig.hasSupabase) {
    await Supabase.initialize(
      url: MobileConfig.supabaseUrl,
      publishableKey: MobileConfig.supabasePublishableKey,
    );
  }
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(const ProviderScope(child: BattleGraphApp()));
}

class BattleGraphApp extends ConsumerWidget {
  const BattleGraphApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'BattleGraph',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
