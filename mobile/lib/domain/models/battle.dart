import 'graph.dart';

/// A BattleGraf battle session.
class Battle {
  final int id;
  final String title;
  final String status;
  final String? currentPlayer;
  final int? currentPlayerId;
  final int? currentTurn;
  final int? turnDuration;
  final int? timeRemaining;
  final Graph? graph;
  final List<Player> players;
  final DateTime? createdAt;
  final DateTime? startedAt;

  const Battle({
    required this.id,
    required this.title,
    required this.status,
    this.currentPlayer,
    this.currentPlayerId,
    this.currentTurn,
    this.turnDuration,
    this.timeRemaining,
    this.graph,
    this.players = const [],
    this.createdAt,
    this.startedAt,
  });

  factory Battle.fromJson(Map<String, dynamic> json) {
    return Battle(
      id: json['id'] as int,
      title: json['title'] as String,
      status: json['status'] as String,
      currentPlayer: json['current_player'] as String?,
      currentPlayerId: json['current_player_id'] as int?,
      currentTurn: json['current_turn'] as int?,
      turnDuration: json['turn_duration'] as int?,
      timeRemaining: json['time_remaining'] as int?,
      graph: json['graph'] != null
          ? Graph.fromJson(json['graph'] as Map<String, dynamic>)
          : null,
      players: (json['players'] as List<dynamic>?)
              ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
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
      'graph': graph?.toJson(),
      'players': players.map((p) => p.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
    };
  }

  Battle copyWith({
    int? id,
    String? title,
    String? status,
    String? currentPlayer,
    int? currentPlayerId,
    int? currentTurn,
    int? turnDuration,
    int? timeRemaining,
    Graph? graph,
    List<Player>? players,
    DateTime? createdAt,
    DateTime? startedAt,
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
      graph: graph ?? this.graph,
      players: players ?? this.players,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

/// A participant in a battle.
class Player {
  final int id;
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
      id: json['id'] as int,
      name: json['name'] as String,
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
