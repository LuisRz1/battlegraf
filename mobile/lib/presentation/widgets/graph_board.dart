import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/graph.dart';
import '../../domain/models/node.dart';

/// A callback invoked when the player taps a node.
typedef NodeTapCallback = void Function(Node node);

/// Interactive graph renderer that draws layered nodes and edges.
class GraphBoard extends StatefulWidget {
  final Graph graph;
  final String? activeNodeId;
  final int currentTurnIndex;
  final Map<int, String> playerPositions;
  final Set<String>? legalNodeIds;
  final bool enableMotion;
  final NodeTapCallback onNodeTap;

  const GraphBoard({
    super.key,
    required this.graph,
    required this.onNodeTap,
    this.activeNodeId,
    this.currentTurnIndex = 0,
    this.playerPositions = const {},
    this.legalNodeIds,
    this.enableMotion = true,
  });

  @override
  State<GraphBoard> createState() => _GraphBoardState();
}

class _GraphBoardState extends State<GraphBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant GraphBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableMotion != widget.enableMotion) {
      _syncMotion();
    }
  }

  void _syncMotion() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.enableMotion || reduceMotion) {
      _controller
        ..stop()
        ..value = .35;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _computeLayout(
          graph: widget.graph,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
        final availableNodeIds =
            widget.legalNodeIds ?? _availableNodeIds(widget.graph);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _GraphPainter(
              graph: widget.graph,
              layout: layout,
              activeNodeId: widget.activeNodeId,
              currentTurnIndex: widget.currentTurnIndex,
              availableNodeIds: availableNodeIds,
              playerPositions: widget.playerPositions,
              pulseValue: _controller.value,
            ),
            child: child,
          ),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) => _handleTap(
                    details.localPosition,
                    layout,
                    availableNodeIds,
                  ),
                ),
              ),
              for (final node in widget.graph.nodes)
                if (availableNodeIds.contains(node.id))
                  Positioned.fromRect(
                    rect: layout.nodes[node]!.inflate(3),
                    child: Semantics(
                      button: true,
                      label: 'Nodo ${node.label}, ${node.subject}, disponible',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onNodeTap(node),
                        child: const ColoredBox(color: Colors.transparent),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  void _handleTap(
    Offset position,
    _GraphLayout layout,
    Set<String> availableNodeIds,
  ) {
    for (final entry in layout.nodes.entries) {
      final node = entry.key;
      final rect = entry.value;
      final shape = NodeShape.fromNode(node);
      if (shape.hitTest(position, rect)) {
        if (availableNodeIds.contains(node.id)) {
          widget.onNodeTap(node);
        }
        return;
      }
    }
  }

  Set<String> _availableNodeIds(Graph graph) {
    final activeOwner = widget.currentTurnIndex == 0
        ? NodeOwner.player
        : NodeOwner.opponent;
    final connections = <(String, String)>{
      for (final edge in graph.edges) (edge.source, edge.target),
      for (final node in graph.nodes)
        for (final target in node.connectedTo) (node.id, target),
    };
    final adjacency = <String, Set<String>>{
      for (final node in graph.nodes) node.id: <String>{},
    };
    for (final connection in connections) {
      adjacency[connection.$1]?.add(connection.$2);
      adjacency[connection.$2]?.add(connection.$1);
    }

    Node? base;
    for (final node in graph.nodes) {
      if (_baseSide(graph, node) == widget.currentTurnIndex) {
        base = node;
        break;
      }
    }
    if (base == null) return const {};

    final nodeById = {for (final node in graph.nodes) node.id: node};
    final sourceId = widget.playerPositions[widget.currentTurnIndex] ?? base.id;
    final source = nodeById[sourceId];
    if (source == null) return const {};

    final available = <String>{};
    for (final targetId in adjacency[sourceId] ?? const <String>{}) {
      final target = nodeById[targetId];
      if (target == null) continue;
      final nextLayer = widget.currentTurnIndex == 0
          ? source.layer + 1
          : source.layer - 1;
      if (target.layer == nextLayer &&
          _effectiveOwner(graph, target) != activeOwner) {
        available.add(targetId);
      }
    }
    return available;
  }

  NodeOwner _effectiveOwner(Graph graph, Node node) {
    if (node.owner != NodeOwner.neutral) return node.owner;
    final baseSide = _baseSide(graph, node);
    if (baseSide == 0) return NodeOwner.player;
    if (baseSide == 1) return NodeOwner.opponent;
    return node.owner;
  }

  int? _baseSide(Graph graph, Node node) {
    if (graph.nodes.isEmpty) return null;
    final layers = graph.nodes.map((item) => item.layer);
    final firstLayer = layers.reduce(min);
    final lastLayer = layers.reduce(max);
    if (node.layer != firstLayer && node.layer != lastLayer) return null;
    final firstAtLayer = graph.nodes
        .where((item) => item.layer == node.layer)
        .reduce(
          (left, right) => left.position <= right.position ? left : right,
        );
    if (node.id != firstAtLayer.id) return null;
    return node.layer == firstLayer ? 0 : 1;
  }

  _GraphLayout _computeLayout({
    required Graph graph,
    required double width,
    required double height,
  }) {
    final padding = EdgeInsets.symmetric(
      horizontal: width * 0.06,
      vertical: height * 0.09,
    );
    final usable = Size(
      max(0, width - padding.left - padding.right),
      max(0, height - padding.top - padding.bottom),
    );

    final layers = <int, List<Node>>{};
    for (final node in graph.nodes) {
      layers.putIfAbsent(node.layer, () => []).add(node);
    }
    final layerKeys = layers.keys.toList()..sort();
    final firstLayer = layerKeys.isEmpty ? 0 : layerKeys.first;
    final lastLayer = layerKeys.isEmpty ? 0 : layerKeys.last;

    final nodeRects = <Node, Rect>{};
    final maxLayerNodes = layers.values.fold<int>(
      1,
      (largest, nodes) => max(largest, nodes.length),
    );
    final visualLayerCount = max(layerKeys.length, graph.layerCount);
    final widthLimit = usable.width / max(maxLayerNodes + .55, 2) * .78;
    final heightLimit = usable.height / max(visualLayerCount + .45, 2) * .68;
    final diameter = min(widthLimit, heightLimit).clamp(42.0, 78.0);
    final nodeSize = Size.square(diameter);

    for (var i = 0; i < layerKeys.length; i++) {
      final layer = layerKeys[i];
      final layerNodes = layers[layer]!
        ..sort((a, b) => a.position.compareTo(b.position));
      final normalizedLayer = lastLayer == firstLayer
          ? .5
          : (layer - firstLayer) / (lastLayer - firstLayer);
      // Layer zero belongs to the red player and is intentionally rendered at
      // the bottom. Advancing through the graph therefore reads bottom-to-top.
      final centerY = padding.top + usable.height * (1 - normalizedLayer);
      final step = layerNodes.length > 1
          ? usable.width / (layerNodes.length + 1)
          : usable.width / 2;

      for (var j = 0; j < layerNodes.length; j++) {
        final node = layerNodes[j];
        final isBase =
            (layer == firstLayer || layer == lastLayer) &&
            node.position == layerNodes.first.position;
        final size = isBase
            ? Size.square((nodeSize.width * 1.38).clamp(58.0, 98.0))
            : nodeSize;
        final centerX = isBase
            ? padding.left + usable.width / 2
            : padding.left + step * (j + 1);
        nodeRects[node] = Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: size.width,
          height: size.height,
        );
      }
    }

    return _GraphLayout(nodes: nodeRects, nodeSize: nodeSize);
  }
}

class _GraphLayout {
  final Map<Node, Rect> nodes;
  final Size nodeSize;

  const _GraphLayout({required this.nodes, required this.nodeSize});
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.graph,
    required this.layout,
    required this.pulseValue,
    required this.currentTurnIndex,
    required this.availableNodeIds,
    required this.playerPositions,
    this.activeNodeId,
  });

  final Graph graph;
  final _GraphLayout layout;
  final String? activeNodeId;
  final int currentTurnIndex;
  final Set<String> availableNodeIds;
  final Map<int, String> playerPositions;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    _drawEdges(canvas);
    for (final entry in layout.nodes.entries) {
      _drawNode(canvas, entry.key, entry.value);
    }
    _drawPlayerPawns(canvas);
  }

  void _drawPlayerPawns(Canvas canvas) {
    final nodeById = {for (final node in layout.nodes.keys) node.id: node};
    for (final entry in playerPositions.entries) {
      final node = nodeById[entry.value];
      final rect = node == null ? null : layout.nodes[node];
      if (rect == null) continue;
      final side = entry.key == 0 ? 0 : 1;
      final color = side == 0 ? AppColors.brightRed : AppColors.neonPurple;
      final center = rect.center.translate(
        side == 0 ? rect.width * .36 : -rect.width * .36,
        side == 0 ? rect.height * .34 : -rect.height * .34,
      );
      final radius = (rect.shortestSide * .15).clamp(8.0, 14.0);
      final pawnPath = Path();
      for (var index = 0; index < 6; index++) {
        final angle = pi / 3 * index;
        final point = Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        );
        if (index == 0) {
          pawnPath.moveTo(point.dx, point.dy);
        } else {
          pawnPath.lineTo(point.dx, point.dy);
        }
      }
      pawnPath.close();
      canvas.drawPath(
        pawnPath,
        Paint()
          ..color = color.withAlpha(220)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            side == currentTurnIndex ? 7 : 3,
          ),
      );
      canvas.drawPath(
        pawnPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        pawnPath,
        Paint()
          ..color = AppColors.offWhite
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      final label = TextPainter(
        text: TextSpan(
          text: side == 0 ? 'R' : 'M',
          style: TextStyle(
            color: AppColors.offWhite,
            fontFamily: AppTheme.displayFont,
            fontSize: radius * .75,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(center.dx - label.width / 2, center.dy - label.height / 2),
      );
    }
  }

  void _drawEdges(Canvas canvas) {
    final glowPaint = Paint()
      ..color = AppColors.neonPurple.withAlpha(65)
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..style = PaintingStyle.stroke;
    final paint = Paint()
      ..color = AppColors.neonPurple.withAlpha(180)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final nodeById = {for (final n in layout.nodes.keys) n.id: n};
    final connections = <(String, String)>{
      for (final edge in graph.edges) (edge.source, edge.target),
      for (final node in graph.nodes)
        for (final target in node.connectedTo) (node.id, target),
    };

    var edgeIndex = 0;
    for (final connection in connections) {
      final source = nodeById[connection.$1];
      final target = nodeById[connection.$2];
      if (source == null || target == null) continue;
      final sourceRect = layout.nodes[source]!;
      final targetRect = layout.nodes[target]!;
      final sourceCenter = sourceRect.center;
      final targetCenter = targetRect.center;
      final path = Path()
        ..moveTo(sourceCenter.dx, sourceCenter.dy)
        ..lineTo(targetCenter.dx, targetCenter.dy);

      final sourceOwner = _effectiveOwner(source);
      final targetOwner = _effectiveOwner(target);
      final ownedConnection =
          sourceOwner != NodeOwner.neutral && sourceOwner == targetOwner;
      final activeOwner = currentTurnIndex == 0
          ? NodeOwner.player
          : NodeOwner.opponent;
      final isFrontier =
          (sourceOwner == activeOwner &&
              availableNodeIds.contains(target.id)) ||
          (targetOwner == activeOwner && availableNodeIds.contains(source.id));
      final routeColor = ownedConnection
          ? _ownerColor(sourceOwner)
          : isFrontier
          ? ownerColorForTurn
          : AppColors.mutedInk;
      glowPaint.color = routeColor.withAlpha(
        ownedConnection
            ? 105
            : isFrontier
            ? 92
            : 28,
      );
      paint.color = routeColor.withAlpha(
        ownedConnection
            ? 235
            : isFrontier
            ? 220
            : 105,
      );
      paint.strokeWidth = ownedConnection
          ? 3.4
          : isFrontier
          ? 3
          : 1.7;
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);

      final packetProgress = (pulseValue + edgeIndex * .19) % 1;
      final packet = Offset.lerp(sourceCenter, targetCenter, packetProgress)!;
      if (ownedConnection || isFrontier) {
        canvas.drawRect(
          Rect.fromCenter(
            center: packet,
            width: isFrontier ? 5 : 4,
            height: isFrontier ? 5 : 4,
          ),
          Paint()
            ..color = (isFrontier ? ownerColorForTurn : routeColor).withAlpha(
              235,
            ),
        );
      }
      edgeIndex++;
    }
  }

  void _drawNode(Canvas canvas, Node node, Rect rect) {
    final baseSide = _baseSide(node);
    final isBase = baseSide != null;
    final isActive =
        node.id == activeNodeId ||
        (baseSide != null && baseSide == currentTurnIndex);
    final isAvailable = availableNodeIds.contains(node.id);
    final shape = NodeShape.fromNode(node);
    final baseColor = node.color(AppColors.darkCard);
    final effectiveOwner = _effectiveOwner(node);
    final ownerColor = _ownerColor(effectiveOwner);
    final fillColor = effectiveOwner == NodeOwner.neutral
        ? Color.lerp(baseColor, AppColors.darkCard, .58)!.withAlpha(225)
        : Color.lerp(ownerColor, AppColors.darkCard, .28)!.withAlpha(238);

    final outerPaint = Paint()
      ..color = isActive
          ? AppColors.offWhite.withAlpha((150 + pulseValue * 100).toInt())
          : isAvailable
          ? AppColors.offWhite.withAlpha((145 + pulseValue * 75).toInt())
          : node.locked
          ? AppColors.mutedInk.withAlpha(80)
          : isBase
          ? ownerColor
          : baseColor
      ..strokeWidth = isActive
          ? 4.5
          : isAvailable
          ? 3.2
          : 2.4
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = (isActive ? baseColor : Colors.black).withAlpha(150)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    shape.drawShadow(canvas, rect, shadowPaint);
    shape.drawFill(canvas, rect, fillPaint);
    shape.drawStroke(canvas, rect, outerPaint);
    if (isAvailable) {
      shape.drawStroke(
        canvas,
        rect.inflate(4 + pulseValue * 2),
        Paint()
          ..color = ownerColorForTurn.withAlpha(70)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
    if (isBase) {
      _drawCastle(canvas, node, rect, ownerColor);
    } else {
      _drawSubjectGlyph(
        canvas,
        node,
        rect,
        effectiveOwner == NodeOwner.neutral ? baseColor : ownerColor,
      );
    }
    _drawLabel(canvas, node, rect);
  }

  void _drawCastle(Canvas canvas, Node node, Rect rect, Color color) {
    final towerRect = Rect.fromCenter(
      center: rect.center.translate(0, -rect.height * .04),
      width: rect.width * .62,
      height: rect.height * .66,
    );
    final fill = Paint()..color = color.withAlpha(node.locked ? 90 : 230);
    final light = Paint()
      ..color = Color.lerp(
        color,
        AppColors.offWhite,
        .55,
      )!.withAlpha(node.locked ? 80 : 235);
    final dark = Paint()..color = AppColors.voidBlack.withAlpha(210);

    canvas.drawRect(
      Rect.fromLTWH(
        towerRect.left + towerRect.width * .16,
        towerRect.top + towerRect.height * .36,
        towerRect.width * .68,
        towerRect.height * .58,
      ),
      fill,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        towerRect.left,
        towerRect.top + towerRect.height * .53,
        towerRect.width * .24,
        towerRect.height * .41,
      ),
      fill,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        towerRect.right - towerRect.width * .24,
        towerRect.top + towerRect.height * .53,
        towerRect.width * .24,
        towerRect.height * .41,
      ),
      fill,
    );
    for (final startX in [
      towerRect.left,
      towerRect.right - towerRect.width * .24,
    ]) {
      for (var block = 0; block < 3; block++) {
        canvas.drawRect(
          Rect.fromLTWH(
            startX + block * towerRect.width * .08,
            towerRect.top + towerRect.height * .47,
            towerRect.width * .055,
            towerRect.height * .1,
          ),
          block.isEven ? light : fill,
        );
      }
    }
    final roof = Path()
      ..moveTo(
        towerRect.left + towerRect.width * .2,
        towerRect.top + towerRect.height * .38,
      )
      ..lineTo(towerRect.center.dx, towerRect.top)
      ..lineTo(
        towerRect.right - towerRect.width * .2,
        towerRect.top + towerRect.height * .38,
      )
      ..close();
    canvas.drawPath(roof, light);
    canvas.drawRect(
      Rect.fromLTWH(
        towerRect.center.dx - towerRect.width * .09,
        towerRect.bottom - towerRect.height * .31,
        towerRect.width * .18,
        towerRect.height * .25,
      ),
      dark,
    );
    for (final dx in [-.26, .26]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(
            towerRect.center.dx + towerRect.width * dx,
            towerRect.center.dy + towerRect.height * .1,
          ),
          width: towerRect.width * .1,
          height: towerRect.height * .14,
        ),
        light,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(
        towerRect.left - towerRect.width * .05,
        towerRect.bottom - towerRect.height * .05,
        towerRect.width * 1.1,
        towerRect.height * .07,
      ),
      light,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        towerRect.center.dx,
        towerRect.top - towerRect.height * .12,
        2,
        towerRect.height * .24,
      ),
      light,
    );
    final flag = Path()
      ..moveTo(towerRect.center.dx + 2, towerRect.top - towerRect.height * .1)
      ..lineTo(
        towerRect.center.dx + towerRect.width * .24,
        towerRect.top - towerRect.height * .03,
      )
      ..lineTo(towerRect.center.dx + 2, towerRect.top + towerRect.height * .05)
      ..close();
    canvas.drawPath(flag, fill);
  }

  void _drawSubjectGlyph(Canvas canvas, Node node, Rect rect, Color color) {
    final subject = node.subject.toLowerCase();
    final mark = switch (subject) {
      'math' || 'mathematics' => 'Σ',
      'language' => 'ABC',
      'science' || 'biology' || 'chemistry' || 'physics' => 'LAB',
      'history' || 'civics' => 'III',
      'geography' => 'MAP',
      'english' => 'EN',
      'art' => 'ART',
      'technology' || 'computing' => 'CPU',
      _ => node.label.substring(0, min(3, node.label.length)).toUpperCase(),
    };
    final painter = TextPainter(
      text: TextSpan(
        text: mark,
        style: TextStyle(
          color: Color.lerp(color, AppColors.offWhite, .7),
          fontFamily: AppTheme.displayFont,
          fontSize: rect.height * (mark.length > 1 ? .15 : .3),
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: color, blurRadius: 9),
            const Shadow(color: AppColors.voidBlack, offset: Offset(2, 2)),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width * .72);
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2 - rect.height * .04,
      ),
    );
  }

  void _drawLabel(Canvas canvas, Node node, Rect rect) {
    final textStyle = TextStyle(
      color: AppColors.offWhite,
      fontFamily: AppTheme.bodyFont,
      fontSize: rect.height * 0.14,
      fontWeight: FontWeight.bold,
      letterSpacing: .5,
    );
    final span = TextSpan(text: node.label, style: textStyle);
    final painter = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: rect.width * 0.9);
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.bottom - painter.height - rect.height * .08,
      ),
    );
  }

  Color _ownerColor(NodeOwner owner) {
    switch (owner) {
      case NodeOwner.player:
        return AppColors.brightRed;
      case NodeOwner.opponent:
        return AppColors.neonPurple;
      case NodeOwner.neutral:
        return AppColors.darkCard;
    }
  }

  Color get ownerColorForTurn =>
      currentTurnIndex == 0 ? AppColors.brightRed : AppColors.neonPurple;

  int? _baseSide(Node node) {
    if (graph.nodes.isEmpty) return null;
    final layers = graph.nodes.map((item) => item.layer);
    final firstLayer = layers.reduce(min);
    final lastLayer = layers.reduce(max);
    if (node.layer != firstLayer && node.layer != lastLayer) return null;
    final firstAtLayer = graph.nodes
        .where((item) => item.layer == node.layer)
        .reduce(
          (left, right) => left.position <= right.position ? left : right,
        );
    if (node.id != firstAtLayer.id) return null;
    return node.layer == firstLayer ? 0 : 1;
  }

  NodeOwner _effectiveOwner(Node node) {
    if (node.owner != NodeOwner.neutral) return node.owner;
    final baseSide = _baseSide(node);
    if (baseSide == 0) return NodeOwner.player;
    if (baseSide == 1) return NodeOwner.opponent;
    return node.owner;
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.activeNodeId != activeNodeId ||
        oldDelegate.layout != layout ||
        oldDelegate.currentTurnIndex != currentTurnIndex ||
        oldDelegate.availableNodeIds != availableNodeIds ||
        oldDelegate.playerPositions != playerPositions ||
        oldDelegate.pulseValue != pulseValue;
  }
}

/// Shape strategies for graph nodes.
abstract class NodeShape {
  factory NodeShape.fromNode(Node node) {
    return const HexagonShape();
  }

  void drawShadow(Canvas canvas, Rect rect, Paint paint);
  void drawFill(Canvas canvas, Rect rect, Paint paint);
  void drawStroke(Canvas canvas, Rect rect, Paint paint);
  bool hitTest(Offset point, Rect rect);
}

class HexagonShape implements NodeShape {
  const HexagonShape();

  Path _path(Rect rect) {
    final path = Path();
    final width = rect.width;
    final height = rect.height;
    final inset = width * 0.25;
    path.moveTo(rect.left + inset, rect.top);
    path.lineTo(rect.right - inset, rect.top);
    path.lineTo(rect.right, rect.top + height / 2);
    path.lineTo(rect.right - inset, rect.bottom);
    path.lineTo(rect.left + inset, rect.bottom);
    path.lineTo(rect.left, rect.top + height / 2);
    path.close();
    return path;
  }

  @override
  void drawShadow(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawPath(_path(rect.translate(4, 4)), paint);
  }

  @override
  void drawFill(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawPath(_path(rect), paint);
  }

  @override
  void drawStroke(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawPath(_path(rect), paint);
  }

  @override
  bool hitTest(Offset point, Rect rect) {
    return _path(rect).contains(point);
  }
}

/// Animated overlay that wraps the graph board for retro feedback.
class GraphBoardWithEffects extends StatelessWidget {
  final Graph graph;
  final String? activeNodeId;
  final NodeTapCallback onNodeTap;
  final bool animateConquest;
  final int currentTurnIndex;
  final Map<int, String> playerPositions;
  final Set<String>? legalNodeIds;
  final bool enableMotion;

  const GraphBoardWithEffects({
    super.key,
    required this.graph,
    required this.onNodeTap,
    this.activeNodeId,
    this.animateConquest = false,
    this.currentTurnIndex = 0,
    this.playerPositions = const {},
    this.legalNodeIds,
    this.enableMotion = true,
  });

  @override
  Widget build(BuildContext context) {
    final board = GraphBoard(
      graph: graph,
      activeNodeId: activeNodeId,
      currentTurnIndex: currentTurnIndex,
      playerPositions: playerPositions,
      legalNodeIds: legalNodeIds,
      enableMotion: enableMotion,
      onNodeTap: onNodeTap,
    );
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!enableMotion || reduceMotion) return board;

    return board
        .animate(target: animateConquest ? 1 : 0)
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.02, 1.02),
          duration: 200.ms,
        )
        .then()
        .scale(
          begin: const Offset(1.02, 1.02),
          end: const Offset(1, 1),
          duration: 200.ms,
        );
  }
}
