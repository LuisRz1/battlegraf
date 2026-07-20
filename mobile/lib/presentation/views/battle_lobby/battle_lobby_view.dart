import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/battle_provider.dart';

/// List of active battles that the player can join or watch.
class BattleLobbyView extends ConsumerStatefulWidget {
  const BattleLobbyView({super.key});

  @override
  ConsumerState<BattleLobbyView> createState() => _BattleLobbyViewState();
}

class _BattleLobbyViewState extends ConsumerState<BattleLobbyView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(battleProvider.notifier).loadActiveBattles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final battleState = ref.watch(battleProvider);
    final battles = battleState.activeBattles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BATALLAS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/lobby'),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.deepPurple, AppColors.royalPurple],
          ),
        ),
        child: SafeArea(
          child: battleState.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              : battles.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      color: AppColors.gold,
                      backgroundColor: AppColors.royalPurple,
                      onRefresh: () async {
                        await ref
                            .read(battleProvider.notifier)
                            .loadActiveBattles();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: battles.length,
                        itemBuilder: (context, index) {
                          final battle = battles[index];
                          final isActive =
                              battle.status.toLowerCase() == 'active' ||
                                  battle.status.toLowerCase() == 'in_progress';
                          return Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _enterBattle(battle.id),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            battle.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium,
                                          ),
                                        ),
                                        _StatusChip(status: battle.status),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Turno: ${battle.currentTurn ?? 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${battle.players.length} jugadores',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                    color: AppColors.gold),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: isActive
                                              ? () => _enterBattle(battle.id)
                                              : null,
                                          child: Text(
                                            isActive ? 'UNIRSE' : 'ESPERAR',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(
                                duration: 400.ms,
                                delay: (index * 80).ms,
                              )
                              .slideX(begin: 0.2);
                        },
                      ),
                    ),
        ),
      ),
    );
  }

  void _enterBattle(int battleId) {
    context.go('/battle/$battleId');
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status.toLowerCase() == 'active' ||
        status.toLowerCase() == 'in_progress';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.gold.withAlpha(60) : AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.gold : AppColors.shadowPurple,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isActive ? AppColors.gold : AppColors.offWhite,
              fontSize: 10,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_kabaddi,
              color: AppColors.gold, size: 64)
              .animate()
              .scale(duration: 600.ms)
              .then()
              .rotate(duration: 600.ms),
          const SizedBox(height: 16),
          Text(
            'No hay batallas activas',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Crea una desde la seccion de maestro',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}
