import 'graph.dart';

/// A BattleGraf battle session.
class Battle {
  final String id;
  final String title;
  final String status;
  final String? currentPlayer;
  final String? currentPlayerId;
  final int? currentTurn;
  final int? turnNumber;
  final int? turnDuration;
  final int? timeRemaining;
  final DateTime? serverTime;
  final DateTime? turnStartedAt;
  final DateTime? turnDeadlineAt;
  final Map<int, String> playerPositions;
  final String? activeNodeId;
  final String? graphId;
  final Graph? graph;
  final List<Player> players;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final String? winnerId;

  const Battle({
    required this.id,
    this.title = 'BATALLA',
    required this.status,
    this.currentPlayer,
    this.currentPlayerId,
    this.currentTurn,
    this.turnNumber,
    this.turnDuration,
    this.timeRemaining,
    this.serverTime,
    this.turnStartedAt,
    this.turnDeadlineAt,
    this.playerPositions = const {},
    this.activeNodeId,
    this.graphId,
    this.graph,
    this.players = const [],
    this.createdAt,
    this.startedAt,
    this.winnerId,
  });

  factory Battle.fromJson(Map<String, dynamic> json) {
    final states = (json['node_states'] as List<dynamic>?) ?? const [];
    final stateByNode = {
      for (final rawState in states)
        (rawState as Map<String, dynamic>)['node_id'].toString(): rawState,
    };
    final rawGraph = json['graph'] as Map<String, dynamic>?;
    Graph? graph;
    if (rawGraph != null) {
      final graphJson = Map<String, dynamic>.from(rawGraph);
      graphJson['nodes'] = (rawGraph['nodes'] as List<dynamic>? ?? const [])
          .map((rawNode) {
            final node = Map<String, dynamic>.from(
              rawNode as Map<String, dynamic>,
            );
            final state = stateByNode[node['id'].toString()];
            if (state != null) node['owner'] = state['owner'];
            return node;
          })
          .toList();
      graph = Graph.fromJson(graphJson);
    }

    final rawPlayers = json['players'] as List<dynamic>?;
    final players = rawPlayers != null
        ? rawPlayers
              .map((e) => Player.fromJson(e as Map<String, dynamic>))
              .toList()
        : [
            if (json['player_1_id'] != null)
              Player(id: json['player_1_id'].toString(), name: 'Jugador 1'),
            if (json['player_2_id'] != null)
              Player(id: json['player_2_id'].toString(), name: 'Jugador 2'),
          ];

    return Battle(
      id: json['id'].toString(),
      title: json['title'] as String? ?? 'BATALLA',
      status: json['status'] as String,
      currentPlayer: json['current_player'] as String?,
      currentPlayerId: json['current_player_id']?.toString(),
      currentTurn: json['current_turn'] as int?,
      turnNumber: json['turn_number'] as int?,
      turnDuration:
          json['turn_timeout_seconds'] as int? ?? json['turn_duration'] as int?,
      timeRemaining: json['time_remaining'] as int?,
      serverTime: _parseDate(json['server_time']),
      turnStartedAt: _parseDate(json['turn_started_at']),
      turnDeadlineAt: _parseDate(json['turn_deadline_at']),
      playerPositions:
          (json['player_positions'] as Map<String, dynamic>? ?? const {}).map(
            (key, value) => MapEntry(int.parse(key), value.toString()),
          ),
      activeNodeId: json['active_node_id']?.toString(),
      graphId: json['graph_id']?.toString(),
      graph: graph,
      players: players,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      winnerId: json['winner_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status,
      'current_player': currentPlayer,
      'current_player_id': currentPlayerId,
      'current_turn': currentTurn,
      'turn_number': turnNumber,
      'turn_duration': turnDuration,
      'time_remaining': timeRemaining,
      'server_time': serverTime?.toIso8601String(),
      'turn_started_at': turnStartedAt?.toIso8601String(),
      'turn_deadline_at': turnDeadlineAt?.toIso8601String(),
      'player_positions': playerPositions.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'active_node_id': activeNodeId,
      'graph_id': graphId,
      'graph': graph?.toJson(),
      'players': players.map((p) => p.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'winner_id': winnerId,
    };
  }

  Battle copyWith({
    String? id,
    String? title,
    String? status,
    String? currentPlayer,
    String? currentPlayerId,
    int? currentTurn,
    int? turnNumber,
    int? turnDuration,
    int? timeRemaining,
    DateTime? serverTime,
    DateTime? turnStartedAt,
    DateTime? turnDeadlineAt,
    Map<int, String>? playerPositions,
    String? activeNodeId,
    String? graphId,
    Graph? graph,
    List<Player>? players,
    DateTime? createdAt,
    DateTime? startedAt,
    String? winnerId,
  }) {
    return Battle(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      currentTurn: currentTurn ?? this.currentTurn,
      turnNumber: turnNumber ?? this.turnNumber,
      turnDuration: turnDuration ?? this.turnDuration,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      serverTime: serverTime ?? this.serverTime,
      turnStartedAt: turnStartedAt ?? this.turnStartedAt,
      turnDeadlineAt: turnDeadlineAt ?? this.turnDeadlineAt,
      playerPositions: playerPositions ?? this.playerPositions,
      activeNodeId: activeNodeId ?? this.activeNodeId,
      graphId: graphId ?? this.graphId,
      graph: graph ?? this.graph,
      players: players ?? this.players,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      winnerId: winnerId ?? this.winnerId,
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}

/// A participant in a battle.
class Player {
  final String id;
  final String name;
  final String? role;
  final int? score;
  final bool isReady;

  const Player({
    required this.id,
    required this.name,
    this.role,
    this.score,
    this.isReady = false,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'].toString(),
      name: json['name'] as String? ?? json['username'] as String? ?? 'Jugador',
      role: json['role'] as String?,
      score: json['score'] as int?,
      isReady: json['is_ready'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'score': score,
      'is_ready': isReady,
    };
  }
}
