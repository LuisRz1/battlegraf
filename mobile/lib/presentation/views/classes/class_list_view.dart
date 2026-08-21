import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../widgets/retro_ui.dart';

class ClassListView extends ConsumerWidget {
  const ClassListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isProfessor = user?['role'] == 'professor';
    final classState = ref.watch(classProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MIS CLASES'),
      ),
      body: BattleBackdrop(
        child: classState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : classState.error != null
                ? Center(
                    child: Text(
                      classState.error!,
                      style: const TextStyle(color: AppColors.brightRed),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: classState.classes.length,
                    itemBuilder: (context, index) {
                      final cls = classState.classes[index];
                      return Card(
                        color: AppColors.panelBackground,
                        child: ListTile(
                          title: Text(
                            cls['name'] ?? '',
                            style: const TextStyle(
                              fontFamily: 'PressStart2P',
                              color: AppColors.gold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            cls['code'] ?? '',
                            style: const TextStyle(
                              color: AppColors.cyan,
                              fontFamily: 'SpaceMono',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.neonPurple,
        onPressed: () {
          if (isProfessor) {
            // Show create dialog or navigate
          } else {
            context.push('/classes/join');
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
