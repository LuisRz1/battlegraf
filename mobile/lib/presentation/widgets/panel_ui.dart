import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Sistema de UI que replica el panel web (global.css):
/// - Fondo piedra #09090C con paneles #14100A
/// - Tarjetas con borde oro #4A3A1C y esquinas 6px
/// - Encabezados: span dorado pequeño + titulo crema (command-title)
/// - Botones dorados .command-btn con texto oscuro
/// - Filas .table-row con separador y hover
/// - .btn-edit (oro) y .btn-del (rojo)

/// [PanelHeader] replica .command-title: span dorado + h1 + descripcion.
class PanelHeader extends StatelessWidget {
  final String span;
  final String title;
  final String? description;
  final Widget? action;
  final bool padded;

  const PanelHeader({
    super.key,
    required this.span,
    required this.title,
    this.description,
    this.action,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padded ? 16 : 0, padded ? 14 : 0, padded ? 16 : 0, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  span.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: AppTheme.displayFont,
                    color: AppColors.oro300,
                    fontSize: 10,
                    letterSpacing: 2.2,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.displayFont,
                    color: AppColors.crema100,
                    fontSize: 20,
                    letterSpacing: 1.6,
                    height: 1.15,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    description!,
                    style: const TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      color: AppColors.crema500,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

/// [PanelBox] replica .game-panel: caja con borde oro, fondo piedra oscuro
/// y cabecera interna (span pequeno + titulo).
class PanelBox extends StatelessWidget {
  final String? span;
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;

  const PanelBox({
    super.key,
    this.span,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.zero,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.fondoPanel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor ?? AppColors.bordeOro, width: 1.3),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (span != null || title != null) ...[
            if (span != null)
              Text(
                span!.toUpperCase(),
                style: const TextStyle(
                  fontFamily: AppTheme.displayFont,
                  color: AppColors.oro300,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
            if (title != null) ...[
              const SizedBox(height: 4),
              Text(
                title!,
                style: const TextStyle(
                  fontFamily: AppTheme.displayFont,
                  color: AppColors.crema100,
                  fontSize: 15,
                  letterSpacing: 1.2,
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(color: AppColors.bordeOro, height: 1, thickness: 1),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

/// [PanelButton] replica .command-btn (fondo oro-500, texto oscuro).
class PanelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool ghost;
  final bool danger;
  final Widget? icon;
  final double? height;

  const PanelButton({
    super.key,
    required this.label,
    this.onTap,
    this.ghost = false,
    this.danger = false,
    this.icon,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    if (danger) {
      bg = AppColors.rojoAccion;
      fg = AppColors.crema100;
      border = AppColors.rojoAccion;
    } else if (ghost) {
      bg = Colors.transparent;
      fg = AppColors.oro300;
      border = AppColors.bordeOro;
    } else {
      bg = AppColors.oro500;
      fg = AppColors.piedra950;
      border = AppColors.oro700;
    }
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          side: BorderSide(color: border, width: 1.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: const TextStyle(
            fontFamily: AppTheme.displayFont,
            fontSize: 11,
            letterSpacing: 1.4,
          ),
        ),
        child: icon != null ? Row(mainAxisSize: MainAxisSize.min, children: [icon!, const SizedBox(width: 6), Text(label)]) : Text(label),
      ),
    );
  }
}

/// [PanelMiniButton] replica .btn-edit / .btn-del (botones pequenos de accion).
class PanelMiniButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  const PanelMiniButton({super.key, required this.label, this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: danger ? const Color(0x22B3202C) : const Color(0x22E6B84D),
        foregroundColor: danger ? AppColors.imperio : AppColors.oro300,
        side: BorderSide(color: danger ? const Color(0xFF5C1B22) : AppColors.bordeOro, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        minimumSize: const Size(0, 26),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontFamily: AppTheme.displayFont,
          fontSize: 10,
          letterSpacing: 1,
        ),
      ),
      child: Text(label),
    );
  }
}

/// [PanelRow] replica .table-row: fila con separador inferior.
class PanelRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final String? tag;
  final Color? tagColor;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final Widget? trailing;

  const PanelRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.tag,
    this.tagColor,
    this.actions = const [],
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.bordeOro, width: 1)),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      color: AppColors.crema100,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        color: AppColors.crema500,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              _PanelTag(label: tag!, color: tagColor ?? AppColors.oro300),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (actions.isNotEmpty) ...[const SizedBox(width: 6), ...actions],
          ],
        ),
      ),
    );
  }
}

class _PanelTag extends StatelessWidget {
  final String label;
  final Color color;

  const _PanelTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withAlpha(140), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTheme.displayFont,
          color: color,
          fontSize: 9,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// [StatPair] replica <dl><div><dt>valor</dt><dd>etiqueta</dd></div>.
class StatPair extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const StatPair({super.key, required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            color: valueColor ?? AppColors.oro300,
            fontSize: 17,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: AppTheme.displayFont,
            color: AppColors.crema500,
            fontSize: 8.5,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

/// [StatStrip] fila de [StatPair] separadas (metrica del panel).
class StatStrip extends StatelessWidget {
  final List<StatPair> stats;

  const StatStrip({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: VerticalDivider(color: AppColors.bordeOro, width: 1, thickness: 1),
            ),
          stats[i],
        ],
      ],
    );
  }
}

/// [SectionChip] chip tipo .grade-chip / materias.
class SectionChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const SectionChip({super.key, required this.label, this.color = AppColors.oro500, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.piedra900,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.bordeOro, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            color: color,
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// [PanelEmpty] estado vacio del panel: icono + mensaje.
class PanelEmpty extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const PanelEmpty({super.key, required this.title, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.bordeOro, size: 44),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.displayFont,
                color: AppColors.oro300,
                fontSize: 13,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.bodyFont,
                color: AppColors.crema500,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}