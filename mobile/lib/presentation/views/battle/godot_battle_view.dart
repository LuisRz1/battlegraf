import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/panel_ui.dart';

/// Batalla con el motor Godot (mapa completo, castillos y animaciones)
/// embebido en la app. Usa el mismo backend y las preguntas del colegio.
class GodotBattleView extends StatefulWidget {
  const GodotBattleView({
    super.key,
    this.topic,
    this.layers,
    this.nodesPerLayer,
    this.botDifficulty = 'balanced',
    this.muted = false,
    this.teams = 2,
  });

  final String? topic;
  final int? layers;
  final int? nodesPerLayer;
  final String botDifficulty;
  final bool muted;
  final int teams;

  @override
  State<GodotBattleView> createState() => _GodotBattleViewState();
}

class _GodotBattleViewState extends State<GodotBattleView> {
  static const String gameHost = 'https://battlegraf-landing-five.vercel.app';

  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;
  bool _ready = false;

  String _buildUrl() {
    final params = <String, String>{
      if (widget.topic != null && widget.topic!.isNotEmpty)
        'subject': widget.topic!,
      if (widget.layers != null && widget.layers! > 0)
        'layers': '${widget.layers}',
      if (widget.nodesPerLayer != null && widget.nodesPerLayer! > 0)
        'nodes': '${widget.nodesPerLayer}',
      'teams': '${widget.teams}',
      'bot_difficulty': widget.botDifficulty,
      if (widget.muted) 'mute': '1',
    };
    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');
    return '$gameHost/game/BattleGraph.html?$query';
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.fondoGame)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _progress = value);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _ready = true);
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            if (error.isForMainFrame ?? false) {
              setState(() => _failed = true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_buildUrl()));
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoGame,
      body: Stack(
        children: [
          Positioned.fill(
            child: _failed
                ? _GodotError(onRetry: _retry)
                : WebViewWidget(controller: _controller),
          ),
          if (!_ready && !_failed)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.fondoGame,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'CARGANDO CAMPO DE BATALLA',
                        style: TextStyle(
                          fontFamily: AppTheme.displayFont,
                          color: AppColors.oro300,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 220,
                        child: LinearProgressIndicator(
                          value: _progress <= 0 ? null : _progress / 100,
                          color: AppColors.oro500,
                          backgroundColor: AppColors.piedra800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 10,
            left: 12,
            child: SafeArea(
              child: PanelButton(
                label: 'SALIR',
                ghost: true,
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/lobby');
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _retry() {
    setState(() {
      _failed = false;
      _ready = false;
      _progress = 0;
    });
    _controller.loadRequest(Uri.parse(_buildUrl()));
  }
}

class _GodotError extends StatelessWidget {
  const _GodotError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'NO SE PUDO CARGAR LA ARENA GODOT',
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              color: AppColors.imperio,
              fontSize: 12,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Revisa tu conexion a internet e intentalo de nuevo.',
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              color: AppColors.crema500,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          PanelButton(label: 'REINTENTAR', onTap: onRetry),
        ],
      ),
    );
  }
}
