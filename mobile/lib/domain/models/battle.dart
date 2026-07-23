import 'graph.dart';

/// A BattleGraf battle session.
class Battle {
  final String id;
  final String title;
  final String status;
  final String? currentPlayer;
  final String? currentPlayerId;
  final int? currentTurn;
  final int? turnDuration;
  final int? timeRemaining;
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
    this.turnDuration,
    this.timeRemaining,
    this.graphId,
    this.graph,
    this.players = const [],
    this.createdAt,
    this.startedAt,
    this.winnerId,
  });

  factory Battle.fromJson(Map<String, dynamic> json) {
    return Battle(
      id: json['id'].toString(),
      title: json['title'] as String? ?? 'BATALLA',
      status: json['status'] as String,
      currentPlayer: json['current_player'] as String?,
      currentPlayerId: json['current_player_id']?.toString(),
      currentTurn: json['current_turn'] as int?,
      turnDuration: json['turn_timeout_seconds'] as int? ?? json['turn_duration'] as int?,
      timeRemaining: json['time_remaining'] as int?,
      graphId: json['graph_id']?.toString(),
      graph: json['graph'] != null
          ? Graph.fromJson(json['graph'] as Map<String, dynamic>)
          : null,
      players: (json['players'] as List<dynamic>?)
              ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
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
      'turn_duration': turnDuration,
      'time_remaining': timeRemaining,
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
    int? turnDuration,
    int? timeRemaining,
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
      turnDuration: turnDuration ?? this.turnDuration,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      graphId: graphId ?? this.graphId,
      graph: graph ?? this.graph,
      players: players ?? this.players,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      winnerId: winnerId ?? this.winnerId,
    );
  }
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
