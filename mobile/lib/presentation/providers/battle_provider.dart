import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/network/api_client.dart';
import '../../domain/models/battle.dart';
import 'auth_provider.dart';

class BattleQuestion {
  final String nodeId;
  final String id;
  final String text;
  final Map<String, String> options;

  const BattleQuestion({
    required this.nodeId,
    required this.id,
    required this.text,
    required this.options,
  });

  factory BattleQuestion.fromJson(Map<String, dynamic> json) {
    return BattleQuestion(
      nodeId: json['node_id'].toString(),
      id: json['question_id'].toString(),
      text: json['text'] as String,
      options: (json['options'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }
}

/// Current battle state exposed to the UI.
class BattleState {
  final Battle? battle;
  final bool isLoading;
  final String? error;
  final String? activeNodeId;
  final BattleQuestion? activeQuestion;
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
    this.activeQuestion,
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
    bool clearActiveNode = false,
    BattleQuestion? activeQuestion,
    bool clearActiveQuestion = false,
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
      activeNodeId: clearActiveNode ? null : activeNodeId ?? this.activeNodeId,
      activeQuestion: clearActiveQuestion
          ? null
          : activeQuestion ?? this.activeQuestion,
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
  BattleNotifier({required this.apiClient, this.userId})
    : super(BattleState(currentUserId: userId)) {
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
        timeRemaining: _remainingFor(battle),
        clearActiveQuestion: true,
      );
      _connectWebSocket(battleId);
      _startTimers(battleId);
      _controller.add(state);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e));
      _controller.add(state);
    }
  }

  Future<Battle?> createBattle(
    String player1Id,
    String player2Id, {
    int numLayers = 4,
    int minNodesPerLayer = 3,
    int maxNodesPerLayer = 4,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.dio.post(
        '/battles',
        data: {
          'player_1_id': player1Id,
          'player_2_id': player2Id,
          'num_layers': numLayers,
          'min_nodes_per_layer': minNodesPerLayer,
          'max_nodes_per_layer': maxNodesPerLayer,
        },
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

  Future<void> answerNode(String nodeId, String answer) async {
    final question = state.activeQuestion;
    if (question == null || question.nodeId != nodeId) return;
    state = state.copyWith(activeNodeId: nodeId);
    try {
      final response = await apiClient.dio.post(
        '/battles/${state.battle?.id}/answer',
        data: {
          'node_id': nodeId,
          'question_id': question.id,
          'chosen_answer': answer,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final success = data['is_correct'] == true;
      _showFeedback(
        data['message'] as String? ??
            (success ? 'Nodo conquistado!' : 'Respuesta incorrecta'),
        success,
      );
      await loadBattle(state.battle!.id);
    } catch (e) {
      _showFeedback(_formatError(e), false);
    }
  }

  Future<bool> selectNode(String nodeId) async {
    try {
      final response = await apiClient.dio.post(
        '/battles/${state.battle?.id}/select-node',
        data: {'node_id': nodeId},
      );
      final question = BattleQuestion.fromJson(
        response.data as Map<String, dynamic>,
      );
      final data = response.data as Map<String, dynamic>;
      final deadline = DateTime.tryParse(
        data['turn_deadline_at']?.toString() ?? '',
      );
      final serverTime = DateTime.tryParse(
        data['server_time']?.toString() ?? '',
      );
      final remaining = deadline != null && serverTime != null
          ? max(
              0,
              (deadline.difference(serverTime).inMilliseconds + 999) ~/ 1000,
            )
          : state.timeRemaining;
      state = state.copyWith(
        activeNodeId: nodeId,
        activeQuestion: question,
        timeRemaining: remaining,
      );
      _controller.add(state);
      return true;
    } catch (error) {
      _showFeedback(_formatError(error), false);
      return false;
    }
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
        final turnChanged = _turnChanged(state.battle, battle);
        state = state.copyWith(
          battle: battle,
          timeRemaining: _remainingFor(battle),
          clearActiveNode: turnChanged,
          clearActiveQuestion: turnChanged,
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
      queryParameters: {
        if (apiClient.dio.options.headers['Authorization']
            case final String auth)
          'token': auth.replaceFirst('Bearer ', ''),
      },
    );
    _channel = WebSocketChannel.connect(wsUrl);
    _channel?.stream.listen(
      (message) {
        final json = jsonDecode(message as String) as Map<String, dynamic>;
        final type = json['type'] as String?;
        if (type == 'battle_update') {
          final battle = Battle.fromJson(
            json['payload'] as Map<String, dynamic>,
          );
          final turnChanged = _turnChanged(state.battle, battle);
          state = state.copyWith(
            battle: battle,
            timeRemaining: _remainingFor(battle),
            clearActiveNode: turnChanged,
            clearActiveQuestion: turnChanged,
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

  bool _turnChanged(Battle? previous, Battle next) {
    if (previous == null) return false;
    if (previous.turnNumber != null && next.turnNumber != null) {
      return previous.turnNumber != next.turnNumber;
    }
    return previous.currentTurn != next.currentTurn;
  }

  int _remainingFor(Battle battle) {
    final deadline = battle.turnDeadlineAt;
    final serverTime = battle.serverTime;
    if (deadline != null && serverTime != null) {
      return max(
        0,
        (deadline.difference(serverTime).inMilliseconds + 999) ~/ 1000,
      );
    }
    return battle.timeRemaining ?? battle.turnDuration ?? 30;
  }

  String _formatError(Object error) {
    if (error is String) return error;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] != null) {
        return data['detail'].toString();
      }
    }
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

final battleProvider = StateNotifierProvider<BattleNotifier, BattleState>((
  ref,
) {
  final authState = ref.watch(authProvider);
  final apiClient = ApiClient(token: authState.token);
  return BattleNotifier(
    apiClient: apiClient,
    userId: authState.user?['id']?.toString(),
  );
});
