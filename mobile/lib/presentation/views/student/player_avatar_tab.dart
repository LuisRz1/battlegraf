import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/solo_journey_provider.dart';
import '../../widgets/panel_ui.dart';
import '../../widgets/player_avatar.dart';

class PlayerAvatarTab extends ConsumerWidget {
  const PlayerAvatarTab({super.key});

  static const _grades = [
    '1ro de primaria',
    '2do de primaria',
    '3ro de primaria',
    '4to de primaria',
    '5to de primaria',
    '6to de primaria',
    '1ro de secundaria',
    '2do de secundaria',
    '3ro de secundaria',
    '4to de secundaria',
    '5to de secundaria',
  ];
  static const _subjects = [
    'Matemática',
    'Comunicación',
    'Ciencia y tecnología',
    'Historia',
    'General',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider);
    final notifier = ref.read(playerProfileProvider.notifier);
    final journey = ref.watch(soloJourneyProvider);
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in profile.catalog) {
      groups.putIfAbsent('${item['slot']}', () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        PanelBox(
          span: 'IDENTIDAD DEL JUGADOR',
          title: 'MI AVATAR',
          child: Row(
            children: [
              PlayerAvatar(config: profile.avatarConfig, size: 82),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.displayFont,
                        color: AppColors.crema100,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${profile.grade} · ${profile.subject}',
                      style: const TextStyle(
                        color: AppColors.crema500,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${journey.completedCount} nodos · ${profile.ownedItems.length} cosméticos',
                      style: const TextStyle(
                        color: AppColors.oro300,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PanelBox(
          span: 'TU CONTEXTO DE APRENDIZAJE',
          title: 'GRADO Y MATERIA',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _grades.contains(profile.grade)
                    ? profile.grade
                    : _grades[4],
                decoration: const InputDecoration(labelText: 'Grado'),
                items: [
                  for (final grade in _grades)
                    DropdownMenuItem(value: grade, child: Text(grade)),
                ],
                onChanged: (value) {
                  if (value != null) notifier.updatePreferences(grade: value);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _subjects.contains(profile.subject)
                    ? profile.subject
                    : _subjects.last,
                decoration: const InputDecoration(labelText: 'Materia inicial'),
                items: [
                  for (final subject in _subjects)
                    DropdownMenuItem(value: subject, child: Text(subject)),
                ],
                onChanged: (value) {
                  if (value != null) notifier.updatePreferences(subject: value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in groups.entries) ...[
          PanelBox(
            span: 'DESBLOQUEOS POR ESTUDIO',
            title: _slotName(entry.key),
            child: Column(
              children: [
                for (final item in entry.value)
                  _CosmeticRow(
                    item: item,
                    owned: profile.ownedItems.contains('${item['item_key']}'),
                    earnedByProgress:
                        journey.completedCount >=
                        ((item['required_completed_nodes'] as num?)?.toInt() ??
                            0),
                    equipped:
                        profile.avatarConfig[entry.key] == item['item_key'],
                    onEquip: () => notifier.equip('${item['item_key']}'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (profile.error != null)
          Text(
            profile.error!,
            style: const TextStyle(color: AppColors.oro300, fontSize: 10),
          ),
        const SizedBox(height: 12),
        PanelBox(
          span: 'CUENTA',
          title: 'TUS DATOS TE PERTENECEN',
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: PanelButton(
                  label: 'SINCRONIZAR AVANCE',
                  ghost: true,
                  onTap: () async {
                    await ref.read(authProvider.notifier).refreshProfile();
                    await ref
                        .read(soloJourneyProvider.notifier)
                        .load(forceCloud: true);
                    await ref.read(playerProfileProvider.notifier).load();
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: PanelButton(
                  label: 'CERRAR SESIÓN',
                  danger: true,
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _slotName(String slot) => switch (slot) {
    'portrait' => 'RETRATO',
    'background' => 'FONDO',
    'frame' => 'MARCO',
    'effect' => 'EFECTO',
    'accessory' => 'ACCESORIO',
    _ => slot.toUpperCase(),
  };
}

class _CosmeticRow extends StatelessWidget {
  const _CosmeticRow({
    required this.item,
    required this.owned,
    required this.earnedByProgress,
    required this.equipped,
    required this.onEquip,
  });

  final Map<String, dynamic> item;
  final bool owned;
  final bool earnedByProgress;
  final bool equipped;
  final Future<bool> Function() onEquip;

  @override
  Widget build(BuildContext context) {
    final canUse = owned || earnedByProgress;
    final threshold = (item['required_completed_nodes'] as num?)?.toInt() ?? 0;
    return PanelRow(
      leading: Icon(
        canUse ? Icons.auto_awesome : Icons.lock_outline,
        color: canUse ? AppColors.oro300 : AppColors.crema500,
      ),
      title: '${item['display_name'] ?? item['item_key']}',
      subtitle: canUse
          ? 'Cosmético permanente · ${item['rarity'] ?? 'común'}'
          : 'Completa $threshold nodos para desbloquear',
      tag: equipped ? 'EQUIPADO' : null,
      tagColor: AppColors.legion,
      actions: canUse && !equipped
          ? [
              PanelMiniButton(
                label: 'EQUIPAR',
                onTap: () async {
                  final equipped = await onEquip();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        equipped
                            ? 'Avatar actualizado.'
                            : 'Sincroniza para equipar este objeto.',
                      ),
                    ),
                  );
                },
              ),
            ]
          : const [],
    );
  }
}
