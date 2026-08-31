import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Animated atmospheric backdrop used by every BattleGraph screen.
class BattleBackdrop extends StatefulWidget {
  final Widget child;
  final bool intense;

  const BattleBackdrop({super.key, required this.child, this.intense = false});

  @override
  State<BattleBackdrop> createState() => _BattleBackdropState();
}

class _BattleBackdropState extends State<BattleBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = .18;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.65, -0.65),
          radius: 1.25,
          colors: [
            Color(0xFF4A126E),
            AppColors.deepPurple,
            AppColors.voidBlack,
          ],
          stops: [0, 0.42, 1],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _BattleBackdropPainter(
            progress: _controller.value,
            intense: widget.intense,
          ),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _BattleBackdropPainter extends CustomPainter {
  final double progress;
  final bool intense;

  const _BattleBackdropPainter({required this.progress, required this.intense});

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final redGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-1.05, .9),
        radius: 1.05,
        colors: [
          AppColors.brightRed.withAlpha(intense ? 115 : 65),
          AppColors.crimsonRed.withAlpha(intense ? 40 : 24),
          Colors.transparent,
        ],
        stops: const [0, .38, 1],
      ).createShader(bounds);
    final purpleGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(1.05, -.85),
        radius: 1.05,
        colors: [
          AppColors.neonPurple.withAlpha(intense ? 125 : 72),
          AppColors.shadowPurple.withAlpha(intense ? 45 : 26),
          Colors.transparent,
        ],
        stops: const [0, .4, 1],
      ).createShader(bounds);
    canvas
      ..drawRect(bounds, redGlow)
      ..drawRect(bounds, purpleGlow);

    final gridPaint = Paint()
      ..color = AppColors.neonPurple.withAlpha(intense ? 34 : 22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const radius = 34.0;
    final hexHeight = math.sqrt(3) * radius;
    final offsetX = progress * radius * 1.5;
    final offsetY = progress * hexHeight;

    for (
      double x = -radius * 3 + offsetX;
      x < size.width + radius * 2;
      x += radius * 1.5
    ) {
      final column = ((x - offsetX) / (radius * 1.5)).round();
      for (
        double y = -hexHeight * 2 + offsetY;
        y < size.height + hexHeight;
        y += hexHeight
      ) {
        final center = Offset(x, y + (column.isOdd ? hexHeight / 2 : 0));
        final redTerritory =
            center.dy / math.max(size.height, 1) >
            center.dx / math.max(size.width, 1);
        gridPaint.color =
            (redTerritory ? AppColors.brightRed : AppColors.neonPurple)
                .withAlpha(intense ? 34 : 22);
        canvas.drawPath(_hexPath(center, radius), gridPaint);
      }
    }

    final starPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 34; i++) {
      final seedX = (i * 83) % 997 / 997;
      final seedY = (i * 191) % 991 / 991;
      final drift = (progress * (8 + i % 5)) % 1;
      final x = (seedX * size.width + drift * 40) % size.width;
      final y = seedY * size.height;
      starPaint.color =
          (i % 5 == 0 ? AppColors.brightRed : AppColors.neonPurple).withAlpha(
            70 + (i % 4) * 28,
          );
      final unit = i % 3 == 0 ? 2.0 : 1.0;
      canvas.drawRect(Rect.fromLTWH(x, y, unit, unit * 2), starPaint);
    }

    final splitPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          AppColors.brightRed.withAlpha(intense ? 34 : 18),
          Colors.transparent,
          AppColors.neonPurple.withAlpha(intense ? 38 : 20),
        ],
      ).createShader(bounds)
      ..strokeWidth = intense ? 2 : 1;
    for (var index = -2; index <= 2; index++) {
      final shift = index * 22 + math.sin(progress * math.pi * 2) * 5;
      canvas.drawLine(
        Offset(-20, size.height * .82 + shift),
        Offset(size.width + 20, size.height * .18 + shift),
        splitPaint,
      );
    }

    final scanlinePaint = Paint()
      ..color = AppColors.voidBlack.withAlpha(intense ? 30 : 20)
      ..strokeWidth = 1;
    for (double y = 1; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }
  }

  Path _hexPath(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 3 * i;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _BattleBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.intense != intense;
}

/// Angular panel with layered neon borders, inspired by a retro game HUD.
class PixelPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accent;
  final bool glow;

  const PixelPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent = AppColors.shadowPurple,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _ChamferClipper(),
      child: Container(
        padding: const EdgeInsets.all(2),
        color: accent,
        child: ClipPath(
          clipper: const _ChamferClipper(),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.darkCard.withAlpha(238),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withAlpha(42),
                  AppColors.darkCard.withAlpha(244),
                  AppColors.voidBlack.withAlpha(245),
                ],
              ),
              boxShadow: glow
                  ? [
                      BoxShadow(
                        color: accent.withAlpha(95),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Small reusable academic tower-node in the same hexagonal language as battle.
class AcademicHexBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double size;

  const AcademicHexBadge({
    super.key,
    required this.label,
    required this.color,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: color.withAlpha(150), blurRadius: 14)],
        ),
        child: ClipPath(
          clipper: const _HexBadgeClipper(),
          child: ColoredBox(
            color: color,
            child: Padding(
              padding: EdgeInsets.all(size * .07),
              child: ClipPath(
                clipper: const _HexBadgeClipper(),
                child: ColoredBox(
                  color: AppColors.voidBlack.withAlpha(235),
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.offWhite,
                        fontFamily: AppTheme.displayFont,
                        fontSize: size * (label.length > 2 ? .14 : .24),
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: color, blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexBadgeClipper extends CustomClipper<Path> {
  const _HexBadgeClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * .25, 0)
      ..lineTo(size.width * .75, 0)
      ..lineTo(size.width, size.height * .5)
      ..lineTo(size.width * .75, size.height)
      ..lineTo(size.width * .25, size.height)
      ..lineTo(0, size.height * .5)
      ..close();
  }

  @override
  bool shouldReclip(covariant _HexBadgeClipper oldClipper) => false;
}

class _ChamferClipper extends CustomClipper<Path> {
  const _ChamferClipper();

  @override
  Path getClip(Size size) {
    final cut = math.min(12.0, size.shortestSide * 0.12);
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Pixel-art school tower used as the visual identity of territories.
class SchoolTower extends StatelessWidget {
  final Color color;
  final double size;
  final bool flagRight;

  const SchoolTower({
    super.key,
    required this.color,
    this.size = 56,
    this.flagRight = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SchoolTowerPainter(color: color, flagRight: flagRight),
    );
  }
}

class _SchoolTowerPainter extends CustomPainter {
  final Color color;
  final bool flagRight;

  const _SchoolTowerPainter({required this.color, required this.flagRight});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shadow = Paint()..color = AppColors.voidBlack.withAlpha(190);
    final fill = Paint()..color = color.withAlpha(210);
    final light = Paint()..color = Color.lerp(color, Colors.white, .48)!;
    final dark = Paint()..color = Color.lerp(color, Colors.black, .42)!;
    final window = Paint()..color = AppColors.offWhite.withAlpha(220);

    canvas.drawRect(Rect.fromLTWH(w * .19, h * .72, w * .68, h * .11), shadow);
    canvas.drawRect(Rect.fromLTWH(w * .22, h * .36, w * .56, h * .43), fill);
    canvas.drawRect(Rect.fromLTWH(w * .14, h * .48, w * .18, h * .31), dark);
    canvas.drawRect(Rect.fromLTWH(w * .68, h * .48, w * .18, h * .31), dark);
    canvas.drawRect(Rect.fromLTWH(w * .35, h * .18, w * .3, h * .61), fill);
    for (final start in [.14, .68]) {
      for (var block = 0; block < 3; block++) {
        canvas.drawRect(
          Rect.fromLTWH(w * (start + block * .06), h * .42, w * .045, h * .09),
          block.isEven ? light : dark,
        );
      }
    }

    final roof = Path()
      ..moveTo(w * .31, h * .2)
      ..lineTo(w * .5, h * .05)
      ..lineTo(w * .69, h * .2)
      ..close();
    canvas.drawPath(roof, light);

    for (final x in [.2, .4, .56, .76]) {
      canvas.drawRect(Rect.fromLTWH(w * x, h * .52, w * .08, h * .1), window);
    }
    canvas.drawRect(Rect.fromLTWH(w * .45, h * .57, w * .1, h * .22), shadow);
    canvas.drawRect(Rect.fromLTWH(w * .46, h * .27, w * .08, h * .1), window);
    canvas.drawRect(Rect.fromLTWH(w * .1, h * .79, w * .8, h * .055), light);

    final poleX = flagRight ? w * .64 : w * .36;
    canvas.drawRect(Rect.fromLTWH(poleX, h * .02, w * .025, h * .25), light);
    final direction = flagRight ? 1.0 : -1.0;
    final flag = Path()
      ..moveTo(poleX, h * .03)
      ..lineTo(poleX + direction * w * .24, h * .08)
      ..lineTo(poleX, h * .15)
      ..close();
    canvas.drawPath(flag, fill);

    final outline = Paint()
      ..color = AppColors.offWhite.withAlpha(190)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, w * .025);
    canvas.drawPath(roof, outline);
  }

  @override
  bool shouldRepaint(covariant _SchoolTowerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.flagRight != flagRight;
}

class HudLabel extends StatelessWidget {
  final String text;
  final Color color;

  const HudLabel(this.text, {super.key, this.color = AppColors.gold});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontFamily: AppTheme.displayFont,
        fontSize: 9,
        letterSpacing: 1.2,
        height: 1.4,
      ),
    );
  }
}
