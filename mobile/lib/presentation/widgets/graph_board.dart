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
  final int? activeNodeId;
  final NodeTapCallback onNodeTap;

  const GraphBoard({
    super.key,
    required this.graph,
    required this.onNodeTap,
    this.activeNodeId,
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
    )..repeat(reverse: true);
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

        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _GraphPainter(
            layout: layout,
            activeNodeId: widget.activeNodeId,
            pulseValue: _controller.value,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) => _handleTap(details.localPosition, layout),
          ),
        );
      },
    );
  }

  void _handleTap(Offset position, _GraphLayout layout) {
    for (final entry in layout.nodes.entries) {
      final node = entry.key;
      final rect = entry.value;
      final shape = NodeShape.fromNode(node);
      if (shape.hitTest(position, rect)) {
        widget.onNodeTap(node);
        return;
      }
    }
  }

  _GraphLayout _computeLayout({
    required Graph graph,
    required double width,
    required double height,
  }) {
    final padding = EdgeInsets.symmetric(
      horizontal: width * 0.08,
      vertical: height * 0.12,
    );
    final usable = Size(
      max(0, width - padding.left - padding.right),
      max(0, height - padding.top - padding.bottom),
    );

    final layers = <int, List<Node>>{};
    for (final node in graph.nodes) {
      layers.putIfAbsent(node.layer, () => []).add(node);
    }
    final layerCount = graph.layerCount;
    final layerKeys = layers.keys.toList()..sort();

    final nodeRects = <Node, Rect>{};
    final nodeSize = Size(
      usable.width / (layerCount + 1) * 0.7,
      usable.height / 6,
    );

    for (var i = 0; i < layerKeys.length; i++) {
      final layer = layerKeys[i];
      final layerNodes = layers[layer]!..sort((a, b) => a.position.compareTo(b.position));
      final layerX = padding.left +
          (usable.width / (layerCount + 1)) * (layer + 1) -
          nodeSize.width / 2;
      final availableHeight = usable.height;
      final step = layerNodes.length > 1
          ? availableHeight / (layerNodes.length + 1)
          : availableHeight / 2;

      for (var j = 0; j < layerNodes.length; j++) {
        final node = layerNodes[j];
        final y = padding.top + step * (j + 1) - nodeSize.height / 2;
        nodeRects[node] = Rect.fromLTWH(layerX, y, nodeSize.width, nodeSize.height);
      }
    }

    return _GraphLayout(
      nodes: nodeRects,
      nodeSize: nodeSize,
    );
  }
}

class _GraphLayout {
  final Map<Node, Rect> nodes;
  final Size nodeSize;

  const _GraphLayout({required this.nodes, required this.nodeSize});
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.layout,
    required this.pulseValue,
    this.activeNodeId,
  });

  final _GraphLayout layout;
  final int? activeNodeId;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    _drawEdges(canvas);
    for (final entry in layout.nodes.entries) {
      _drawNode(canvas, entry.key, entry.value);
    }
  }

  void _drawEdges(Canvas canvas) {
    final paint = Paint()
      ..color = AppColors.gold.withAlpha(120)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final node in layout.nodes.keys) {
      final sourceRect = layout.nodes[node];
      if (sourceRect == null) continue;
      final sourceCenter = sourceRect.center;

      for (final target in layout.nodes.keys) {
        if (target.layer == node.layer + 1) {
          final targetRect = layout.nodes[target];
          if (targetRect == null) continue;
          final path = Path();
          path.moveTo(sourceCenter.dx, sourceCenter.dy);
          path.quadraticBezierTo(
            (sourceCenter.dx + targetRect.center.dx) / 2,
            sourceCenter.dy,
            targetRect.center.dx,
            targetRect.center.dy,
          );
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  void _drawNode(Canvas canvas, Node node, Rect rect) {
    final isActive = node.id == activeNodeId;
    final shape = NodeShape.fromNode(node);
    final baseColor = node.color(AppColors.darkCard);
    final ownerColor = _ownerColor(node.owner);
    final fillColor = node.owner == NodeOwner.neutral
        ? baseColor.withAlpha(160)
        : ownerColor.withAlpha(200);

    final outerPaint = Paint()
      ..color = isActive
          ? AppColors.gold.withAlpha((100 + pulseValue * 120).toInt())
          : AppColors.gold
      ..strokeWidth = isActive ? 3.5 : 1.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(120)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    shape.drawShadow(canvas, rect, shadowPaint);
    shape.drawFill(canvas, rect, fillPaint);
    shape.drawStroke(canvas, rect, outerPaint);
    _drawLabel(canvas, node, rect);
  }

  void _drawLabel(Canvas canvas, Node node, Rect rect) {
    final textStyle = TextStyle(
      color: node.owner == NodeOwner.neutral
          ? AppColors.offWhite
          : AppColors.offWhite,
      fontFamily: AppTheme.bodyFont,
      fontSize: rect.height * 0.22,
      fontWeight: FontWeight.bold,
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
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  Color _ownerColor(NodeOwner owner) {
    switch (owner) {
      case NodeOwner.player:
        return AppColors.brightRed;
      case NodeOwner.opponent:
        return AppColors.royalPurple;
      case NodeOwner.neutral:
        return AppColors.darkCard;
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.activeNodeId != activeNodeId ||
        oldDelegate.layout != layout ||
        oldDelegate.pulseValue != pulseValue;
  }
}

/// Shape strategies for graph nodes.
abstract class NodeShape {
  factory NodeShape.fromNode(Node node) {
    if (node.layer == 0) return const CardShape();
    return const HexagonShape();
  }

  void drawShadow(Canvas canvas, Rect rect, Paint paint);
  void drawFill(Canvas canvas, Rect rect, Paint paint);
  void drawStroke(Canvas canvas, Rect rect, Paint paint);
  bool hitTest(Offset point, Rect rect);
}

class CardShape implements NodeShape {
  const CardShape();

  RRect _rrect(Rect rect) {
    final radius = Radius.circular(rect.shortestSide * 0.18);
    return RRect.fromRectAndRadius(rect, radius);
  }

  @override
  void drawShadow(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawRRect(_rrect(rect.translate(4, 4)), paint);
  }

  @override
  void drawFill(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawRRect(_rrect(rect), paint);
  }

  @override
  void drawStroke(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawRRect(_rrect(rect), paint);
  }

  @override
  bool hitTest(Offset point, Rect rect) => _rrect(rect).contains(point);
}

class HexagonShape implements NodeShape {
  const HexagonShape();

  Path _path(Rect rect) {
    final path = Path();
    final width = rect.width;
    final height = rect.height;
    final inset = width * 0.12;
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
  final int? activeNodeId;
  final NodeTapCallback onNodeTap;
  final bool animateConquest;

  const GraphBoardWithEffects({
    super.key,
    required this.graph,
    required this.onNodeTap,
    this.activeNodeId,
    this.animateConquest = false,
  });

  @override
  Widget build(BuildContext context) {
    return GraphBoard(
      graph: graph,
      activeNodeId: activeNodeId,
      onNodeTap: onNodeTap,
    )
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
