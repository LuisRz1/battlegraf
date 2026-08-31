import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import 'retro_ui.dart';

/// Compact game HUD used instead of a platform AppBar.
class RetroScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color accent;

  const RetroScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actionLabel,
    this.onAction,
    this.accent = AppColors.neonPurple,
  });

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      accent: accent,
      glow: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          if (onBack != null) ...[
            RetroActionButton(
              label: 'VOLVER',
              onPressed: onBack,
              accent: AppColors.shadowPurple,
              compact: true,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.offWhite,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 10),
            RetroActionButton(
              label: actionLabel!,
              onPressed: onAction,
              accent: accent,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Angular, high-contrast action without Material's rounded button treatment.
class RetroActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final bool compact;
  final Key? buttonKey;

  const RetroActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.accent = AppColors.brightRed,
    this.compact = false,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final activeColor = enabled ? accent : AppColors.shadowPurple;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: buttonKey,
          onTap: onPressed,
          splashColor: activeColor.withAlpha(80),
          highlightColor: activeColor.withAlpha(45),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: BoxConstraints(minHeight: compact ? 42 : 48),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 16,
              vertical: compact ? 7 : 11,
            ),
            decoration: BoxDecoration(
              color: AppColors.voidBlack.withAlpha(enabled ? 220 : 150),
              border: Border.all(color: activeColor, width: 2),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: activeColor.withAlpha(75),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  color: enabled ? AppColors.offWhite : AppColors.mutedInk,
                  fontFamily: AppTheme.displayFont,
                  fontSize: compact ? 7 : 9,
                  letterSpacing: compact ? .5 : .8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Branded loading state that remains legible without a Material spinner.
class PixelLoader extends StatelessWidget {
  final String label;
  final Color color;

  const PixelLoader({
    super.key,
    this.label = 'CARGANDO',
    this.color = AppColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SchoolTower(color: color, size: 62)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: .92, end: 1.05, duration: 700.ms),
          const SizedBox(height: 12),
          HudLabel(label, color: color),
        ],
      ),
    );
  }
}

/// Dialog shell matching the angular neon panels used throughout the game.
class RetroDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Color accent;

  const RetroDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.accent = AppColors.neonPurple,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: PixelPanel(
          accent: accent,
          glow: true,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AcademicHexBadge(label: 'BG', color: accent, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .55,
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: child,
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(spacing: 8, runSpacing: 8, children: actions),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Alternative selector rendered as an academic hex badge instead of a radio.
class HexOptionTile extends StatelessWidget {
  final String code;
  final String text;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  const HexOptionTile({
    super.key,
    required this.code,
    required this.text,
    required this.selected,
    required this.onTap,
    this.accent = AppColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.offWhite : accent;
    return Semantics(
      button: true,
      selected: selected,
      label: '$code. $text',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withAlpha(70)
                  : AppColors.voidBlack.withAlpha(185),
              border: Border.all(color: borderColor, width: selected ? 2 : 1),
            ),
            child: Row(
              children: [
                AcademicHexBadge(
                  label: code,
                  color: selected ? AppColors.offWhite : accent,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected ? AppColors.offWhite : AppColors.mutedInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showRetroMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final accent = isError ? AppColors.brightRed : AppColors.cyan;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: PixelPanel(
          accent: accent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: HudLabel(message, color: accent),
        ),
      ),
    );
}
