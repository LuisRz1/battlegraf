import 'dart:ui';

/// Owner of a graph node.
enum NodeOwner { neutral, player, opponent }

/// A playable node in a BattleGraf graph.
class Node {
  final String id;
  final String label;
  final String subject;
  final int layer;
  final int position;
  final NodeOwner owner;
  final bool locked;
  final String? question;
  final List<String> options;
  final String? conqueredBy;
  final List<String> connectedTo;
  final List<String> questionIds;

  const Node({
    required this.id,
    required this.label,
    required this.subject,
    required this.layer,
    required this.position,
    this.owner = NodeOwner.neutral,
    this.locked = false,
    this.question,
    this.options = const [],
    this.conqueredBy,
    this.connectedTo = const [],
    this.questionIds = const [],
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? json['subject'] as String,
      subject: json['subject'] as String,
      layer: json['layer'] as int,
      position: json['position'] as int? ?? 0,
      owner: _parseOwner(json['owner'] as String?),
      locked: json['locked'] as bool? ?? false,
      question: json['question'] as String?,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      conqueredBy: json['conquered_by']?.toString(),
      connectedTo: (json['connected_to'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      questionIds: (json['question_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'subject': subject,
      'layer': layer,
      'position': position,
      'owner': _ownerToString(owner),
      'locked': locked,
      'question': question,
      'options': options,
      'conquered_by': conqueredBy,
      'connected_to': connectedTo,
      'question_ids': questionIds,
    };
  }

  Node copyWith({
    String? id,
    String? label,
    String? subject,
    int? layer,
    int? position,
    NodeOwner? owner,
    bool? locked,
    String? question,
    List<String>? options,
    String? conqueredBy,
    List<String>? connectedTo,
    List<String>? questionIds,
  }) {
    return Node(
      id: id ?? this.id,
      label: label ?? this.label,
      subject: subject ?? this.subject,
      layer: layer ?? this.layer,
      position: position ?? this.position,
      owner: owner ?? this.owner,
      locked: locked ?? this.locked,
      question: question ?? this.question,
      options: options ?? this.options,
      conqueredBy: conqueredBy ?? this.conqueredBy,
      connectedTo: connectedTo ?? this.connectedTo,
      questionIds: questionIds ?? this.questionIds,
    );
  }

  static NodeOwner _parseOwner(String? value) {
    if (value == null || value == 'neutral') return NodeOwner.neutral;
    if (value == '0' || value == 'player') return NodeOwner.player;
    if (value == '1' || value == 'opponent') return NodeOwner.opponent;
    return NodeOwner.neutral;
  }

  static String _ownerToString(NodeOwner owner) {
    switch (owner) {
      case NodeOwner.player:
        return 'player';
      case NodeOwner.opponent:
        return 'opponent';
      case NodeOwner.neutral:
        return 'neutral';
    }
  }

  Color color(Color fallback) {
    return _subjectColors[subject.toLowerCase()] ?? fallback;
  }

  static final Map<String, Color> _subjectColors = {
    'math': const Color(0xFFE63946),
    'mathematics': const Color(0xFFE63946),
    'language': const Color(0xFFF4A261),
    'science': const Color(0xFF2A9D8F),
    'physics': const Color(0xFF264653),
    'chemistry': const Color(0xFFE76F51),
    'biology': const Color(0xFF06A77D),
    'history': const Color(0xFF9B5DE5),
    'geography': const Color(0xFF00B4D8),
    'english': const Color(0xFFF15BB5),
    'art': const Color(0xFF8338EC),
    'civics': const Color(0xFF3A86FF),
    'physical_education': const Color(0xFFFB5607),
    'technology': const Color(0xFF38B000),
    'philosophy': const Color(0xFFFFBE0B),
    'religion': const Color(0xFF8AC926),
    'computing': const Color(0xFFFF006E),
  };
}
