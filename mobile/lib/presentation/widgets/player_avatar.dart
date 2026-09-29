import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    this.config = const {},
    this.size = 64,
    this.onTap,
  });

  final Map<String, dynamic> config;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final portrait = '${config['portrait'] ?? 'portrait_nova'}';
    final background = '${config['background'] ?? 'background_sky'}';
    final frame = '${config['frame'] ?? 'frame_copper'}';
    final accessory = '${config['accessory'] ?? ''}';
    final portraitColor = portrait == 'portrait_terra'
        ? AppColors.aliados
        : AppColors.oro500;
    final backgroundColor = background == 'background_nebula'
        ? AppColors.violeta900
        : AppColors.piedra900;
    final frameColor = frame == 'frame_prism'
        ? AppColors.violeta400
        : AppColors.oro700;

    return Semantics(
      button: onTap != null,
      label: 'Avatar del alumno',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: size,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: frameColor, width: size * .055),
              boxShadow: [
                BoxShadow(
                  color: frameColor.withValues(alpha: .38),
                  blurRadius: size * .22,
                ),
              ],
            ),
            child: ClipOval(
              child: CustomPaint(
                size: Size.square(size),
                painter: _PixelAvatarPainter(
                  portrait: portrait,
                  background: background,
                  accessory: accessory,
                  portraitColor: portraitColor,
                  backgroundColor: backgroundColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelAvatarPainter extends CustomPainter {
  const _PixelAvatarPainter({
    required this.portrait,
    required this.background,
    required this.accessory,
    required this.portraitColor,
    required this.backgroundColor,
  });

  final String portrait;
  final String background;
  final String accessory;
  final Color portraitColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 16;
    final fill = Paint()..style = PaintingStyle.fill;
    void block(int x, int y, int width, int height, Color color) {
      fill.color = color;
      canvas.drawRect(
        Rect.fromLTWH(x * unit, y * unit, width * unit, height * unit),
        fill,
      );
    }

    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    block(2, 2, 1, 1, AppColors.oro300.withValues(alpha: .8));
    block(12, 4, 1, 1, AppColors.crema100.withValues(alpha: .8));
    block(3, 7, 1, 1, AppColors.violeta400.withValues(alpha: .8));

    final hair = portrait == 'portrait_terra'
        ? const Color(0xFF4B252B)
        : const Color(0xFF281D37);
    const skin = Color(0xFFE7B98B);
    final coat = portraitColor;

    // Block-built bust keeps the portrait crisp at small sizes.
    block(2, 12, 12, 4, hair);
    block(3, 12, 10, 4, coat);
    block(5, 10, 6, 3, skin);
    block(4, 5, 8, 6, skin);
    block(3, 5, 2, 5, hair);
    block(11, 5, 2, 5, hair);
    block(4, 4, 8, 2, hair);
    block(5, 7, 1, 1, AppColors.piedra950);
    block(10, 7, 1, 1, AppColors.piedra950);
    block(7, 9, 3, 1, const Color(0xFF9C4B4D));

    if (accessory == 'accessory_comet') {
      block(10, 1, 4, 1, AppColors.oro300);
      block(12, 2, 2, 2, AppColors.oro500);
      block(14, 3, 1, 1, AppColors.crema100);
    }
    if (accessory.isNotEmpty && accessory != 'accessory_comet') {
      block(5, 2, 6, 1, AppColors.oro300);
      block(6, 1, 4, 1, AppColors.oro500);
      block(7, 0, 2, 1, AppColors.oro300);
    }
    if (background == 'background_nebula') {
      block(1, 11, 2, 1, AppColors.violeta400);
      block(13, 9, 1, 2, AppColors.neonPurple);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelAvatarPainter oldDelegate) =>
      oldDelegate.portrait != portrait ||
      oldDelegate.background != background ||
      oldDelegate.accessory != accessory ||
      oldDelegate.portraitColor != portraitColor ||
      oldDelegate.backgroundColor != backgroundColor;
}
