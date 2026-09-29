import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/player_avatar.dart';
import 'player_avatar_tab.dart';
import 'solo_route_view.dart';
import 'student_activity_tab.dart';
import 'student_home_tab.dart';
import 'student_school_tab.dart';

class StudentAppShell extends ConsumerStatefulWidget {
  const StudentAppShell({super.key});

  @override
  ConsumerState<StudentAppShell> createState() => _StudentAppShellState();
}

class _StudentAppShellState extends ConsumerState<StudentAppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user ?? const <String, dynamic>{};
    final hasSchool = auth.hasSchoolMembership;
    final isPersonal = auth.isPersonalMode;
    final schoolName = user['school_name']?.toString() ?? 'Colegio vinculado';
    final displayName = user['full_name']?.toString() ?? 'Explorador';
    final avatarConfig = Map<String, dynamic>.from(
      user['avatar_config'] as Map? ?? const {},
    );
    final tabs = <_StudentTab>[
      const _StudentTab('INICIO', Icons.home_outlined),
      _StudentTab(
        isPersonal ? 'RUTA' : 'COLEGIO',
        isPersonal ? Icons.route_outlined : Icons.school_outlined,
      ),
      const _StudentTab('ACTIVIDAD', Icons.bolt_outlined),
      const _StudentTab('AVATAR', Icons.face_retouching_natural_outlined),
    ];
    final pages = <Widget>[
      StudentHomeTab(
        displayName: displayName,
        schoolName: hasSchool ? schoolName : null,
        isPersonal: isPersonal,
        onContinue: () => setState(() => _selectedIndex = 1),
        onLinkSchool: _showSchoolCodeDialog,
      ),
      isPersonal ? const SoloRouteView() : const StudentSchoolTab(),
      StudentActivityTab(isPersonal: isPersonal),
      const PlayerAvatarTab(),
    ];

    if (_selectedIndex >= pages.length) _selectedIndex = 0;

    return Scaffold(
      backgroundColor: AppColors.fondoGame,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _StudentTopBar(
              displayName: displayName,
              schoolName: hasSchool ? schoolName : null,
              isPersonal: isPersonal,
              hasSchool: hasSchool,
              isOffline: auth.isOffline,
              avatarConfig: avatarConfig,
              onSwitchMode: hasSchool ? _toggleMode : _showSchoolCodeDialog,
              onAvatarTap: () => setState(() => _selectedIndex = 3),
            ),
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: pages),
            ),
            _StudentBottomBar(
              tabs: tabs,
              selectedIndex: _selectedIndex,
              onSelect: (index) => setState(() => _selectedIndex = index),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleMode() async {
    final auth = ref.read(authProvider);
    if (!auth.hasSchoolMembership) {
      await _showSchoolCodeDialog();
      return;
    }
    final target = auth.isPersonalMode ? 'school' : 'personal';
    final changed = await ref
        .read(authProvider.notifier)
        .setStudentMode(target);
    if (!mounted) return;
    if (!changed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cambiar el espacio activo.')),
      );
      return;
    }
    setState(() => _selectedIndex = 0);
  }

  Future<void> _showSchoolCodeDialog() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.piedra900,
        title: const Text('VINCULAR COLEGIO'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 64,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Código del colegio',
            hintText: 'BG-XXXX',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('VINCULAR'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty || !mounted) return;
    final joined = await ref.read(authProvider.notifier).joinSchoolByCode(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          joined
              ? 'Colegio vinculado. Tu campaña personal sigue guardada.'
              : ref.read(authProvider).error ??
                    'No se pudo vincular el código.',
        ),
      ),
    );
    if (joined) setState(() => _selectedIndex = 0);
  }
}

class _StudentTab {
  const _StudentTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _StudentTopBar extends StatelessWidget {
  const _StudentTopBar({
    required this.displayName,
    required this.schoolName,
    required this.isPersonal,
    required this.hasSchool,
    required this.isOffline,
    required this.avatarConfig,
    required this.onSwitchMode,
    required this.onAvatarTap,
  });

  final String displayName;
  final String? schoolName;
  final bool isPersonal;
  final bool hasSchool;
  final bool isOffline;
  final Map<String, dynamic> avatarConfig;
  final VoidCallback onSwitchMode;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      decoration: const BoxDecoration(
        color: AppColors.piedra950,
        border: Border(bottom: BorderSide(color: AppColors.bordeOro, width: 1)),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/panel_logo.webp',
            width: 90,
            height: 38,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.castle_outlined,
              color: AppColors.oro300,
              size: 32,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.displayFont,
                    color: AppColors.crema100,
                    fontSize: 11,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isPersonal ? 'RUTA PERSONAL' : schoolName ?? 'COLEGIO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    color: AppColors.crema500,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (isOffline)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.cloud_off, color: AppColors.oro300, size: 18),
            ),
          if (hasSchool)
            PopupMenuButton<String>(
              tooltip: 'Cambiar espacio',
              onSelected: (_) => onSwitchMode(),
              color: AppColors.piedra900,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: isPersonal ? 'school' : 'personal',
                  child: Text(isPersonal ? 'ABRIR COLEGIO' : 'RUTA PERSONAL'),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.fondoPanel,
                  border: Border.all(color: AppColors.bordeOro),
                ),
                child: Icon(
                  isPersonal ? Icons.school_outlined : Icons.explore_outlined,
                  color: AppColors.oro300,
                  size: 18,
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Vincular colegio',
              onPressed: onSwitchMode,
              icon: const Icon(Icons.add_link, color: AppColors.oro300),
            ),
          const SizedBox(width: 6),
          PlayerAvatar(config: avatarConfig, size: 38, onTap: onAvatarTap),
        ],
      ),
    );
  }
}

class _StudentBottomBar extends StatelessWidget {
  const _StudentBottomBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_StudentTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.piedra950,
        border: Border(top: BorderSide(color: AppColors.bordeOro, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x77000000),
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        5,
        5,
        5,
        MediaQuery.paddingOf(context).bottom + 3,
      ),
      child: Row(
        children: [
          for (var index = 0; index < tabs.length; index++)
            Expanded(
              child: Semantics(
                button: true,
                selected: index == selectedIndex,
                label: tabs[index].label,
                child: InkWell(
                  key: ValueKey(
                    'student-tab-${tabs[index].label.toLowerCase()}',
                  ),
                  onTap: () => onSelect(index),
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 2,
                    ),
                    decoration: BoxDecoration(
                      color: index == selectedIndex
                          ? AppColors.imperio.withValues(alpha: .14)
                          : Colors.transparent,
                      border: Border.all(
                        color: index == selectedIndex
                            ? AppColors.imperio
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tabs[index].icon,
                          size: 19,
                          color: index == selectedIndex
                              ? AppColors.oro300
                              : AppColors.crema500,
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tabs[index].label,
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: AppTheme.displayFont,
                              fontSize: 8,
                              letterSpacing: .35,
                              color: index == selectedIndex
                                  ? AppColors.crema100
                                  : AppColors.crema500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
