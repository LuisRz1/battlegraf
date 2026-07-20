import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/network/api_client.dart';
import '../../domain/models/battle.dart';
import 'auth_provider.dart';

/// Current battle state exposed to the UI.
class BattleState {
  final Battle? battle;
  final bool isLoading;
  final String? error;
  final int? activeNodeId;
  final String? feedback;
  final bool feedbackSuccess;
  final int timeRemaining;
  final List<Battle> activeBattles;

  const BattleState({
    this.battle,
    this.isLoading = false,
    this.error,
    this.activeNodeId,
    this.feedback,
    this.feedbackSuccess = false,
    this.timeRemaining = 0,
    this.activeBattles = const [],
  });

  BattleState copyWith({
    Battle? battle,
    bool? isLoading,
    String? error,
    int? activeNodeId,
    String? feedback,
    bool? feedbackSuccess,
    int? timeRemaining,
    List<Battle>? activeBattles,
  }) {
    return BattleState(
      battle: battle ?? this.battle,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeNodeId: activeNodeId ?? this.activeNodeId,
      feedback: feedback,
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      activeBattles: activeBattles ?? this.activeBattles,
    );
  }
}

/// Notifier that manages a battle lifecycle: polling, timer and WebSocket updates.
class BattleNotifier extends StateNotifier<BattleState> {
  BattleNotifier({required this.apiClient}) : super(const BattleState()) {
    _controller = StreamController<BattleState>.broadcast();
  }

  final ApiClient apiClient;
  late final StreamController<BattleState> _controller;
  WebSocketChannel? _channel;
  Timer? _refreshTimer;
  Timer? _countdownTimer;

  @override
  Stream<BattleState> get stream => _controller.stream;

  Future<void> loadActiveBattles() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.dio.get('/battles');
      final data = response.data as List<dynamic>;
      final battles = data
          .map((json) => Battle.fromJson(json as Map<String, dynamic>))
          .toList();
      state = state.copyWith(isLoading: false, activeBattles: battles);
      _controller.add(state);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e));
      _controller.add(state);
    }
  }

  Future<void> loadBattle(int battleId) async {
    state = state.copyWith(isLoading: true, error: null);
    _stopTimers();
    try {
      final response = await apiClient.dio.get('/battles/$battleId');
      final battle = Battle.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(
        isLoading: false,
        battle: battle,
        timeRemaining: battle.timeRemaining ?? battle.turnDuration,
      );
      _connectWebSocket(battleId);
      _startTimers(battleId);
      _controller.add(state);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e));
      _controller.add(state);
    }
  }

  Future<void> joinBattle(int battleId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await apiClient.dio.post('/battles/$battleId/join');
      await loadBattle(battleId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e));
      _controller.add(state);
    }
  }

  Future<void> answerNode(int nodeId, String answer) async {
    state = state.copyWith(activeNodeId: nodeId);
    try {
      final response = await apiClient.dio.post(
        '/battles/${state.battle?.id}/answer',
        data: {'node_id': nodeId, 'answer': answer},
      );
      final success = (response.data as Map<String, dynamic>)['correct'] == true;
      _showFeedback(
        success ? 'Nodo conquistado!' : 'Respuesta incorrecta',
        success,
      );
    } catch (e) {
      _showFeedback(_formatError(e), false);
    }
  }

  void selectNode(int nodeId) {
    state = state.copyWith(activeNodeId: nodeId);
  }

  void clearFeedback() {
    state = state.copyWith(feedback: null);
  }

  void _showFeedback(String message, bool success) {
    state = state.copyWith(feedback: message, feedbackSuccess: success);
    _controller.add(state);
    Future.delayed(const Duration(seconds: 2), clearFeedback);
  }

  void _startTimers(int battleId) {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final response = await apiClient.dio.get('/battles/$battleId');
        final battle = Battle.fromJson(response.data as Map<String, dynamic>);
        state = state.copyWith(
          battle: battle,
          timeRemaining: battle.timeRemaining ?? battle.turnDuration,
        );
        _controller.add(state);
      } catch (_) {
        // Silent refresh failures keep the UI stable.
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = max(0, state.timeRemaining - 1);
      state = state.copyWith(timeRemaining: next);
      _controller.add(state);
    });
  }

  void _connectWebSocket(int battleId) {
    _channel?.sink.close();
    final baseUri = Uri.parse(apiClient.dio.options.baseUrl);
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final wsUrl = Uri(
      scheme: wsScheme,
      host: baseUri.host,
      port: baseUri.port,
      path: '/ws/battles/$battleId',
    );
    _channel = WebSocketChannel.connect(wsUrl);
    _channel?.stream.listen(
      (message) {
        final json = jsonDecode(message as String) as Map<String, dynamic>;
        final type = json['type'] as String?;
        if (type == 'battle_update') {
          final battle = Battle.fromJson(json['payload'] as Map<String, dynamic>);
          state = state.copyWith(
            battle: battle,
            timeRemaining: battle.timeRemaining ?? battle.turnDuration,
          );
          _controller.add(state);
        } else if (type == 'node_conquered') {
          final nodeId = json['node_id'] as int?;
          _showFeedback('Nodo $nodeId conquistado!', true);
        }
      },
      onError: (_) {
        // WebSocket errors are non-fatal; REST polling continues.
      },
    );
  }

  void _stopTimers() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _refreshTimer = null;
    _countdownTimer = null;
  }

  String _formatError(Object error) {
    if (error is String) return error;
    return 'Error de conexion';
  }

  @override
  void dispose() {
    _stopTimers();
    _channel?.sink.close();
    _controller.close();
    super.dispose();
  }
}

final battleProvider = StateNotifierProvider<BattleNotifier, BattleState>((ref) {
  final authState = ref.watch(authProvider);
  final apiClient = ApiClient(token: authState.token);
  return BattleNotifier(apiClient: apiClient);
});
