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
  final String? activeNodeId;
  final String? feedback;
  final bool feedbackSuccess;
  final int timeRemaining;
  final List<Battle> activeBattles;
  final String? currentUserId;

  const BattleState({
    this.battle,
    this.isLoading = false,
    this.error,
    this.activeNodeId,
    this.feedback,
    this.feedbackSuccess = false,
    this.timeRemaining = 0,
    this.activeBattles = const [],
    this.currentUserId,
  });

  BattleState copyWith({
    Battle? battle,
    bool? isLoading,
    String? error,
    String? activeNodeId,
    String? feedback,
    bool? feedbackSuccess,
    int? timeRemaining,
    List<Battle>? activeBattles,
    String? currentUserId,
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
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }
}

/// Notifier that manages a battle lifecycle: polling, timer and WebSocket updates.
class BattleNotifier extends StateNotifier<BattleState> {
  BattleNotifier({required this.apiClient, this.userId}) : super(const BattleState()) {
    _controller = StreamController<BattleState>.broadcast();
  }

  final ApiClient apiClient;
  final String? userId;
  late final StreamController<BattleState> _controller;
  WebSocketChannel? _channel;
  Timer? _refreshTimer;
  Timer? _countdownTimer;

  @override
  Stream<BattleState> get stream => _controller.stream;

  Future<void> loadActiveBattles() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.dio.get('/battles/me');
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

  Future<void> loadBattle(String battleId) async {
    state = state.copyWith(isLoading: true, error: null);
    _stopTimers();
    try {
      final response = await apiClient.dio.get('/battles/$battleId');
      final battle = Battle.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(
        isLoading: false,
        battle: battle,
        timeRemaining: battle.timeRemaining ?? battle.turnDuration ?? 30,
      );
      _connectWebSocket(battleId);
      _startTimers(battleId);
      _controller.add(state);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e));
      _controller.add(state);
    }
  }

  Future<Battle?> createBattle(String player1Id, String player2Id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.dio.post(
        '/battles',
        data: {'player_1_id': player1Id, 'player_2_id': player2Id},
      );
      final battle = Battle.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(isLoading: false, battle: battle);
      _controller.add(state);
      return battle;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e));
      _controller.add(state);
      return null;
    }
  }

  Future<bool> startBattle(String battleId) async {
    try {
      await apiClient.dio.post('/battles/$battleId/start', data: {});
      await loadBattle(battleId);
      return true;
    } catch (e) {
      _showFeedback(_formatError(e), false);
      return false;
    }
  }

  Future<void> answerNode(String nodeId, String questionId, String answer) async {
    state = state.copyWith(activeNodeId: nodeId);
    try {
      final response = await apiClient.dio.post(
        '/battles/${state.battle?.id}/answer',
        data: {
          'node_id': nodeId,
          'question_id': questionId,
          'chosen_answer': answer,
          'response_time_ms': 1500,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final success = data['is_correct'] == true;
      _showFeedback(
        data['message'] as String? ?? (success ? 'Nodo conquistado!' : 'Respuesta incorrecta'),
        success,
      );
      await loadBattle(state.battle!.id);
    } catch (e) {
      _showFeedback(_formatError(e), false);
    }
  }

  void selectNode(String nodeId) {
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

  void _startTimers(String battleId) {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final response = await apiClient.dio.get('/battles/$battleId');
        final battle = Battle.fromJson(response.data as Map<String, dynamic>);
        state = state.copyWith(
          battle: battle,
          timeRemaining: battle.timeRemaining ?? battle.turnDuration ?? 30,
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

  void _connectWebSocket(String battleId) {
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
            timeRemaining: battle.timeRemaining ?? battle.turnDuration ?? 30,
          );
          _controller.add(state);
        } else if (type == 'node_conquered') {
          final nodeId = json['node_id']?.toString();
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
  return BattleNotifier(apiClient: apiClient, userId: authState.user?['id']?.toString());
});
