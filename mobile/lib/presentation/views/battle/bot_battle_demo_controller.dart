import 'package:flutter/foundation.dart';

import '../../../domain/models/graph.dart';
import '../../../domain/models/node.dart';

enum DemoBattleSide { red, purple }

enum DemoBattlePhase { chooseNode, answerQuestion, botThinking, finished }

class DemoQuestion {
  final String id;
  final String nodeId;
  final String subject;
  final String prompt;
  final Map<String, String> options;
  final String correctOption;

  const DemoQuestion({
    required this.id,
    required this.nodeId,
    required this.subject,
    required this.prompt,
    required this.options,
    required this.correctOption,
  });
}

/// Local, deterministic battle used by the public prototype.
///
/// It deliberately uses the same [Graph] and [Node] types as online battles so
/// the board is not a separate mock. The only simulated part is the rival:
/// every purple turn chooses a legal frontier node and resolves one question.
class BotBattleDemoController extends ChangeNotifier {
  BotBattleDemoController() {
    _restoreInitialState();
  }

  static const redBaseId = 'red-base';
  static const purpleBaseId = 'purple-base';

  late Graph _graph;
  DemoBattleSide _currentSide = DemoBattleSide.red;
  DemoBattlePhase _phase = DemoBattlePhase.chooseNode;
  DemoBattleSide? _winner;
  String? _selectedNodeId;
  String? _lastMoveNodeId;
  String? _redPositionId;
  String? _purplePositionId;
  String _statusMessage = 'Tu turno: elige un hexágono conectado.';
  int _turnNumber = 1;
  int _redCorrect = 0;
  int _redAttempts = 0;
  int _purpleCorrect = 0;
  int _purpleAttempts = 0;
  int _botMoveCount = 0;
  bool? _lastMoveWasCorrect;
  final Map<String, int> _captureMillis = {};

  Graph get graph => _graph;
  DemoBattleSide get currentSide => _currentSide;
  DemoBattlePhase get phase => _phase;
  DemoBattleSide? get winner => _winner;
  String? get selectedNodeId => _selectedNodeId;
  String? get lastMoveNodeId => _lastMoveNodeId;
  String get statusMessage => _statusMessage;
  int get turnNumber => _turnNumber;
  int get redCorrect => _redCorrect;
  int get redAttempts => _redAttempts;
  int get purpleCorrect => _purpleCorrect;
  int get purpleAttempts => _purpleAttempts;
  bool? get lastMoveWasCorrect => _lastMoveWasCorrect;
  bool get isFinished => _phase == DemoBattlePhase.finished;

  Map<int, String> get playerPositions => {
    if (_redPositionId != null) 0: _redPositionId!,
    if (_purplePositionId != null) 1: _purplePositionId!,
  };

  DemoQuestion? get activeQuestion {
    final nodeId = _selectedNodeId;
    return nodeId == null ? null : _questionsByNode[nodeId];
  }

  Set<String> get legalNodeIds => _legalNodesFor(_currentSide);

  int ownedNodes(DemoBattleSide side) {
    final owner = _ownerFor(side);
    return _graph.nodes.where((node) => node.owner == owner).length;
  }

  bool selectNode(String nodeId) {
    if (_phase != DemoBattlePhase.chooseNode ||
        _currentSide != DemoBattleSide.red ||
        !legalNodeIds.contains(nodeId)) {
      return false;
    }

    _selectedNodeId = nodeId;
    _lastMoveNodeId = nodeId;
    _phase = DemoBattlePhase.answerQuestion;
    _lastMoveWasCorrect = null;
    _statusMessage = 'Responde para conquistar ${_node(nodeId).label}.';
    notifyListeners();
    return true;
  }

  bool submitPlayerAnswer(String optionId, {int elapsedMilliseconds = 3000}) {
    final question = activeQuestion;
    if (_phase != DemoBattlePhase.answerQuestion ||
        _currentSide != DemoBattleSide.red ||
        question == null ||
        !question.options.containsKey(optionId)) {
      return false;
    }

    _redAttempts += 1;
    final correct = optionId == question.correctOption;
    if (correct) {
      _redCorrect += 1;
    }
    _resolveMove(
      DemoBattleSide.red,
      question.nodeId,
      correct,
      elapsedMilliseconds: elapsedMilliseconds,
    );
    notifyListeners();
    return correct;
  }

  /// Resolves one purple turn. The view controls the short thinking delay so
  /// tests remain fast and deterministic.
  void resolveBotTurn() {
    if (_phase != DemoBattlePhase.botThinking ||
        _currentSide != DemoBattleSide.purple ||
        isFinished) {
      return;
    }

    final targets = legalNodeIds.toList()
      ..sort((a, b) {
        final aNode = _node(a);
        final bNode = _node(b);
        final layerOrder = aNode.layer.compareTo(bNode.layer);
        if (layerOrder != 0) return layerOrder;
        final centerA = (aNode.position - 1.5).abs();
        final centerB = (bNode.position - 1.5).abs();
        return centerA.compareTo(centerB);
      });

    if (targets.isEmpty) {
      _passTurn('El BOT no tiene una ruta legal.');
      notifyListeners();
      return;
    }

    final targetId = targets.first;
    _selectedNodeId = targetId;
    _lastMoveNodeId = targetId;
    _purpleAttempts += 1;

    // Three hits out of every four moves makes the rival credible while
    // keeping the prototype winnable for a first-time player.
    final botElapsedMilliseconds = const [
      7200,
      5200,
      3800,
      6400,
    ][_botMoveCount % 4];
    final correct = _botMoveCount % 4 != 2;
    _botMoveCount += 1;
    if (correct) {
      _purpleCorrect += 1;
    }
    _resolveMove(
      DemoBattleSide.purple,
      targetId,
      correct,
      elapsedMilliseconds: botElapsedMilliseconds,
    );
    notifyListeners();
  }

  void handlePlayerTimeout() {
    if (_currentSide != DemoBattleSide.red ||
        (_phase != DemoBattlePhase.chooseNode &&
            _phase != DemoBattlePhase.answerQuestion) ||
        isFinished) {
      return;
    }

    _redAttempts += 1;
    _lastMoveWasCorrect = false;
    _passTurn('Tiempo agotado.');
    notifyListeners();
  }

  void reset() {
    _restoreInitialState();
    notifyListeners();
  }

  void _resolveMove(
    DemoBattleSide side,
    String nodeId,
    bool answeredCorrectly, {
    required int elapsedMilliseconds,
  }) {
    final node = _node(nodeId);
    _lastMoveWasCorrect = answeredCorrectly;

    if (!answeredCorrectly) {
      final actor = side == DemoBattleSide.red
          ? 'Respuesta incorrecta'
          : 'El BOT falló';
      _passTurn('$actor en ${node.label}.');
      return;
    }

    final owner = _ownerFor(side);
    final contested = node.owner != NodeOwner.neutral && node.owner != owner;
    final standingRecord = _captureMillis[nodeId];
    if (contested &&
        standingRecord != null &&
        elapsedMilliseconds >= standingRecord) {
      final delta = (elapsedMilliseconds - standingRecord) / 1000;
      _passTurn(
        'Acertaste en ${node.label}, pero el récord rival fue '
        '${delta.toStringAsFixed(1)} s más rápido.',
      );
      return;
    }

    _captureMillis[nodeId] = elapsedMilliseconds;
    _setNodeOwner(nodeId, owner);
    if (side == DemoBattleSide.red) {
      _redPositionId = nodeId;
    } else {
      _purplePositionId = nodeId;
    }

    final conqueredRivalBase =
        (side == DemoBattleSide.red && nodeId == purpleBaseId) ||
        (side == DemoBattleSide.purple && nodeId == redBaseId);
    if (conqueredRivalBase) {
      _winner = side;
      _phase = DemoBattlePhase.finished;
      _selectedNodeId = null;
      _statusMessage = side == DemoBattleSide.red
          ? 'Victoria: conquistaste la torre rival.'
          : 'Derrota: el BOT conquistó tu torre.';
      return;
    }

    final actor = side == DemoBattleSide.red
        ? 'Conquistaste'
        : 'El BOT conquistó';
    _passTurn('$actor ${node.label}.');
  }

  void _passTurn(String result) {
    _currentSide = _currentSide == DemoBattleSide.red
        ? DemoBattleSide.purple
        : DemoBattleSide.red;
    _turnNumber += 1;
    _selectedNodeId = null;
    _phase = _currentSide == DemoBattleSide.red
        ? DemoBattlePhase.chooseNode
        : DemoBattlePhase.botThinking;
    _statusMessage = _currentSide == DemoBattleSide.red
        ? '$result Tu turno: elige una ruta conectada.'
        : '$result Turno del BOT.';
  }

  Set<String> _legalNodesFor(DemoBattleSide side) {
    if (isFinished) return const {};

    final owner = _ownerFor(side);
    final adjacency = _adjacency;
    final currentPositionId = side == DemoBattleSide.red
        ? _redPositionId ?? redBaseId
        : _purplePositionId ?? purpleBaseId;
    final source = _node(currentPositionId);
    final legal = <String>{};
    for (final targetId in adjacency[currentPositionId] ?? const <String>{}) {
      final target = _node(targetId);
      final nextLayer = side == DemoBattleSide.red
          ? source.layer + 1
          : source.layer - 1;
      if (target.layer == nextLayer && target.owner != owner) {
        legal.add(targetId);
      }
    }
    return legal;
  }

  Map<String, Set<String>> get _adjacency {
    final result = <String, Set<String>>{
      for (final node in _graph.nodes) node.id: <String>{},
    };
    for (final edge in _graph.edges) {
      result[edge.source]?.add(edge.target);
      result[edge.target]?.add(edge.source);
    }
    for (final node in _graph.nodes) {
      for (final connectedId in node.connectedTo) {
        result[node.id]?.add(connectedId);
        result[connectedId]?.add(node.id);
      }
    }
    return result;
  }

  void _setNodeOwner(String nodeId, NodeOwner owner) {
    _graph = _graph.copyWith(
      nodes: [
        for (final node in _graph.nodes)
          if (node.id == nodeId)
            node.copyWith(
              owner: owner,
              conqueredBy: owner == NodeOwner.player
                  ? 'demo-player'
                  : 'demo-bot',
            )
          else
            node,
      ],
    );
  }

  Node _node(String id) => _graph.nodes.firstWhere((node) => node.id == id);

  static NodeOwner _ownerFor(DemoBattleSide side) {
    return side == DemoBattleSide.red ? NodeOwner.player : NodeOwner.opponent;
  }

  void _restoreInitialState() {
    _graph = _buildGraph();
    _currentSide = DemoBattleSide.red;
    _phase = DemoBattlePhase.chooseNode;
    _winner = null;
    _selectedNodeId = null;
    _lastMoveNodeId = null;
    _redPositionId = redBaseId;
    _purplePositionId = purpleBaseId;
    _statusMessage = 'Tu turno: elige un hexágono conectado.';
    _turnNumber = 1;
    _redCorrect = 0;
    _redAttempts = 0;
    _purpleCorrect = 0;
    _purpleAttempts = 0;
    _botMoveCount = 0;
    _lastMoveWasCorrect = null;
    _captureMillis.clear();
  }

  static Graph _buildGraph() {
    const nodes = [
      Node(
        id: redBaseId,
        label: 'TORRE ROJA',
        subject: 'base',
        layer: 0,
        position: 0,
        owner: NodeOwner.player,
      ),
      Node(id: 'math-1', label: 'M1', subject: 'math', layer: 1, position: 0),
      Node(
        id: 'language-1',
        label: 'C1',
        subject: 'language',
        layer: 1,
        position: 1,
      ),
      Node(
        id: 'science-1',
        label: 'CT1',
        subject: 'science',
        layer: 1,
        position: 2,
      ),
      Node(
        id: 'history-2',
        label: 'H2',
        subject: 'history',
        layer: 2,
        position: 0,
      ),
      Node(id: 'math-2', label: 'M2', subject: 'math', layer: 2, position: 1),
      Node(
        id: 'science-2',
        label: 'CT2',
        subject: 'science',
        layer: 2,
        position: 2,
      ),
      Node(
        id: 'language-2',
        label: 'C2',
        subject: 'language',
        layer: 2,
        position: 3,
      ),
      Node(
        id: 'science-3',
        label: 'CT3',
        subject: 'science',
        layer: 3,
        position: 0,
      ),
      Node(
        id: 'history-3',
        label: 'H3',
        subject: 'history',
        layer: 3,
        position: 1,
      ),
      Node(id: 'math-3', label: 'M3', subject: 'math', layer: 3, position: 2),
      Node(
        id: purpleBaseId,
        label: 'TORRE MORADA',
        subject: 'base',
        layer: 4,
        position: 0,
        owner: NodeOwner.opponent,
      ),
    ];

    const edges = [
      GraphEdge(source: redBaseId, target: 'math-1'),
      GraphEdge(source: redBaseId, target: 'language-1'),
      GraphEdge(source: redBaseId, target: 'science-1'),
      GraphEdge(source: 'math-1', target: 'history-2'),
      GraphEdge(source: 'math-1', target: 'math-2'),
      GraphEdge(source: 'language-1', target: 'history-2'),
      GraphEdge(source: 'language-1', target: 'language-2'),
      GraphEdge(source: 'science-1', target: 'science-2'),
      GraphEdge(source: 'science-1', target: 'language-2'),
      GraphEdge(source: 'history-2', target: 'history-3'),
      GraphEdge(source: 'history-2', target: 'science-3'),
      GraphEdge(source: 'math-2', target: 'history-3'),
      GraphEdge(source: 'math-2', target: 'math-3'),
      GraphEdge(source: 'science-2', target: 'science-3'),
      GraphEdge(source: 'science-2', target: 'math-3'),
      GraphEdge(source: 'language-2', target: 'science-3'),
      GraphEdge(source: 'language-2', target: 'math-3'),
      GraphEdge(source: 'science-3', target: purpleBaseId),
      GraphEdge(source: 'history-3', target: purpleBaseId),
      GraphEdge(source: 'math-3', target: purpleBaseId),
    ];

    return const Graph(nodes: nodes, edges: edges, layerCount: 5);
  }

  static const Map<String, DemoQuestion> _questionsByNode = {
    redBaseId: DemoQuestion(
      id: 'q-red-base',
      nodeId: redBaseId,
      subject: 'Defensa escolar',
      prompt: '¿Qué acción fortalece una convivencia respetuosa en el aula?',
      options: {
        'A': 'Escuchar y dialogar ante un desacuerdo',
        'B': 'Ignorar todas las opiniones',
        'C': 'Imponer una respuesta sin explicar',
        'D': 'Excluir a quien piensa diferente',
      },
      correctOption: 'A',
    ),
    'math-1': DemoQuestion(
      id: 'q-math-1',
      nodeId: 'math-1',
      subject: 'Matemática',
      prompt: '¿Cuál es el resultado de 3/4 + 1/4?',
      options: {'A': '1/2', 'B': '1', 'C': '4/8', 'D': '2'},
      correctOption: 'B',
    ),
    'language-1': DemoQuestion(
      id: 'q-language-1',
      nodeId: 'language-1',
      subject: 'Comunicación',
      prompt: '¿Cuál es la idea principal de un texto?',
      options: {
        'A': 'El dato menos importante',
        'B': 'El nombre del autor',
        'C': 'El mensaje central que organiza el texto',
        'D': 'La última palabra',
      },
      correctOption: 'C',
    ),
    'science-1': DemoQuestion(
      id: 'q-science-1',
      nodeId: 'science-1',
      subject: 'Ciencia y tecnología',
      prompt: '¿Qué órgano bombea la sangre por el cuerpo?',
      options: {
        'A': 'El corazón',
        'B': 'El estómago',
        'C': 'El pulmón',
        'D': 'El riñón',
      },
      correctOption: 'A',
    ),
    'history-2': DemoQuestion(
      id: 'q-history-2',
      nodeId: 'history-2',
      subject: 'Historia',
      prompt: '¿Qué fuente ayuda a investigar hechos del pasado?',
      options: {
        'A': 'Solo rumores',
        'B': 'Documentos, objetos y testimonios',
        'C': 'Únicamente predicciones',
        'D': 'Ninguna evidencia',
      },
      correctOption: 'B',
    ),
    'math-2': DemoQuestion(
      id: 'q-math-2',
      nodeId: 'math-2',
      subject: 'Matemática',
      prompt: 'Si 5x = 35, ¿cuánto vale x?',
      options: {'A': '5', 'B': '6', 'C': '7', 'D': '8'},
      correctOption: 'C',
    ),
    'science-2': DemoQuestion(
      id: 'q-science-2',
      nodeId: 'science-2',
      subject: 'Ciencia y tecnología',
      prompt: '¿Cuál es un cambio físico de la materia?',
      options: {
        'A': 'Quemar papel',
        'B': 'Oxidar hierro',
        'C': 'Derretir hielo',
        'D': 'Cocinar un huevo',
      },
      correctOption: 'C',
    ),
    'language-2': DemoQuestion(
      id: 'q-language-2',
      nodeId: 'language-2',
      subject: 'Comunicación',
      prompt: '¿Cuál oración usa correctamente la coma?',
      options: {
        'A': 'Ana compró, pan leche y fruta.',
        'B': 'Ana, compró pan leche y fruta.',
        'C': 'Ana compró pan, leche y fruta.',
        'D': 'Ana compró pan leche, y fruta.',
      },
      correctOption: 'C',
    ),
    'science-3': DemoQuestion(
      id: 'q-science-3',
      nodeId: 'science-3',
      subject: 'Ciencia y tecnología',
      prompt: '¿Qué proceso permite a las plantas producir su alimento?',
      options: {
        'A': 'Evaporación',
        'B': 'Fotosíntesis',
        'C': 'Condensación',
        'D': 'Erosión',
      },
      correctOption: 'B',
    ),
    'history-3': DemoQuestion(
      id: 'q-history-3',
      nodeId: 'history-3',
      subject: 'Historia',
      prompt: '¿Para qué sirve una línea de tiempo?',
      options: {
        'A': 'Ordenar acontecimientos cronológicamente',
        'B': 'Medir la temperatura',
        'C': 'Resolver una ecuación',
        'D': 'Clasificar seres vivos',
      },
      correctOption: 'A',
    ),
    'math-3': DemoQuestion(
      id: 'q-math-3',
      nodeId: 'math-3',
      subject: 'Matemática',
      prompt: '¿Cuál es el área de un rectángulo de 6 por 4 unidades?',
      options: {'A': '10', 'B': '20', 'C': '24', 'D': '28'},
      correctOption: 'C',
    ),
    purpleBaseId: DemoQuestion(
      id: 'q-purple-base',
      nodeId: purpleBaseId,
      subject: 'Conquista final',
      prompt: '¿Qué estrategia de estudio favorece un aprendizaje duradero?',
      options: {
        'A': 'Repasar con pausas y explicar lo aprendido',
        'B': 'Memorizar sin comprender una sola vez',
        'C': 'Evitar toda retroalimentación',
        'D': 'Estudiar únicamente después del examen',
      },
      correctOption: 'A',
    ),
  };
}
