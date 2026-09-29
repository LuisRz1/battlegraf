import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/models/solo_campaign.dart';
import 'auth_provider.dart';

class SoloProgressEntry {
  const SoloProgressEntry({
    required this.nodeId,
    required this.score,
    required this.stars,
    required this.completedAt,
  });

  final String nodeId;
  final int score;
  final int stars;
  final DateTime completedAt;

  factory SoloProgressEntry.fromJson(Map<String, dynamic> json) {
    return SoloProgressEntry(
      nodeId: '${json['node_id'] ?? json['nodeId'] ?? ''}',
      score: (json['score'] as num?)?.toInt() ?? 0,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      completedAt:
          DateTime.tryParse('${json['completed_at'] ?? json['completedAt']}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toLocalJson() => {
    'node_id': nodeId,
    'score': score,
    'stars': stars,
    'completed_at': completedAt.toUtc().toIso8601String(),
  };
}

class SoloJourneyState {
  const SoloJourneyState({
    this.isLoading = false,
    this.error,
    this.completed = const {},
    this.selectedRoute,
  });

  final bool isLoading;
  final String? error;
  final Map<String, SoloProgressEntry> completed;
  final String? selectedRoute;

  int get completedCount =>
      completed.keys.where((key) => !key.startsWith('branch_')).length;

  int get experience => completed.values.fold<int>(
    0,
    (total, entry) => total + 20 + entry.score ~/ 10,
  );

  bool isComplete(String nodeId) => completed.containsKey(nodeId);

  bool isUnlocked(SoloCampaignNode node) {
    if (isComplete(node.id)) return true;
    return switch (node.id) {
      'first_step' => true,
      'path_choice' => isComplete('first_step') && selectedRoute == null,
      'forest_lesson' => selectedRoute == 'forest',
      'ruins_lesson' => selectedRoute == 'ruins',
      'forest_treasure' =>
        selectedRoute == 'forest' && isComplete('forest_lesson'),
      'ruins_treasure' =>
        selectedRoute == 'ruins' && isComplete('ruins_lesson'),
      'castle_gate' =>
        (selectedRoute == 'forest' && isComplete('forest_treasure')) ||
            (selectedRoute == 'ruins' && isComplete('ruins_treasure')),
      'castle_boss' => isComplete('castle_gate'),
      _ => false,
    };
  }

  List<SoloProgressEntry> get recentActivity =>
      completed.values.toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
}

class SoloJourneyNotifier extends StateNotifier<SoloJourneyState> {
  SoloJourneyNotifier({
    required this.playerProfileId,
    required this.campaign,
    bool startOffline = false,
  }) : _cloudAvailable = !startOffline,
       super(const SoloJourneyState(isLoading: true));

  final String? playerProfileId;
  final SoloCampaignDefinition campaign;
  bool _cloudAvailable;
  static const _localProgressPrefix = 'battlegraf.solo.v1';
  static const _cloudNodeOrder = [
    'first_step',
    'path_choice',
    'branch_forest',
    'branch_ruins',
    'forest_lesson',
    'ruins_lesson',
    'forest_treasure',
    'ruins_treasure',
    'castle_gate',
    'castle_boss',
  ];

  String get _storageKey =>
      '$_localProgressPrefix.${playerProfileId ?? 'offline'}.${campaign.id}';

  Future<void> load({bool forceCloud = false}) async {
    state = SoloJourneyState(
      isLoading: true,
      completed: state.completed,
      selectedRoute: state.selectedRoute,
    );
    final merged = <String, SoloProgressEntry>{};
    final cloudNodeIds = <String>{};
    final staleCloudNodeIds = <String>{};
    String? selectedRoute;
    var cloudAvailable = false;

    try {
      final preferences = await SharedPreferences.getInstance();
      final local = preferences.getString(_storageKey);
      if (local != null) {
        final decoded = jsonDecode(local);
        if (decoded is Map) {
          selectedRoute = decoded['selected_route']?.toString();
          final entries = decoded['completed'];
          if (entries is List) {
            for (final entry in entries.whereType<Map>()) {
              final parsed = SoloProgressEntry.fromJson(
                Map<String, dynamic>.from(entry),
              );
              if (parsed.nodeId.isNotEmpty) merged[parsed.nodeId] = parsed;
            }
          }
        }
      }
    } catch (_) {
      // A corrupt local cache should not make the learner lose access.
    }

    if (playerProfileId != null && (_cloudAvailable || forceCloud)) {
      try {
        final rows = await supabase.Supabase.instance.client
            .from('solo_campaign_progress')
            .select('node_id, completed, score, stars, completed_at')
            .eq('player_profile_id', playerProfileId!)
            .eq('campaign_id', campaign.id)
            .eq('completed', true)
            .timeout(const Duration(seconds: 4));
        cloudAvailable = true;
        _cloudAvailable = true;
        for (final raw in List<Map<String, dynamic>>.from(rows)) {
          final entry = SoloProgressEntry.fromJson(raw);
          cloudNodeIds.add(entry.nodeId);
          if (entry.nodeId.startsWith('branch_')) {
            selectedRoute = entry.nodeId.substring('branch_'.length);
            continue;
          }
          final local = merged[entry.nodeId];
          if (local == null) {
            merged[entry.nodeId] = entry;
          } else {
            if (local.score > entry.score ||
                local.stars > entry.stars ||
                local.completedAt.isAfter(entry.completedAt)) {
              staleCloudNodeIds.add(entry.nodeId);
            }
            merged[entry.nodeId] = SoloProgressEntry(
              nodeId: entry.nodeId,
              score: local.score > entry.score ? local.score : entry.score,
              stars: local.stars > entry.stars ? local.stars : entry.stars,
              completedAt: entry.completedAt.isAfter(local.completedAt)
                  ? entry.completedAt
                  : local.completedAt,
            );
          }
        }
      } catch (_) {
        _cloudAvailable = false;
        // Continue with the offline copy when the account or network is unavailable.
      }
    }

    state = SoloJourneyState(
      completed: Map.unmodifiable(merged),
      selectedRoute: selectedRoute,
    );
    await _saveLocal();
    if (cloudAvailable) {
      await _syncPendingCloud(cloudNodeIds.difference(staleCloudNodeIds));
    }
  }

  Future<bool> chooseRoute(String routeId) async {
    if (!state.isUnlocked(campaign.node('path_choice')) ||
        state.selectedRoute != null ||
        !{'forest', 'ruins'}.contains(routeId)) {
      return false;
    }
    final chosenAt = DateTime.now().toUtc();
    final completed = {
      ...state.completed,
      'path_choice': SoloProgressEntry(
        nodeId: 'path_choice',
        score: 0,
        stars: 0,
        completedAt: chosenAt,
      ),
    };
    state = SoloJourneyState(
      completed: Map.unmodifiable(completed),
      selectedRoute: routeId,
    );
    await _saveLocal();
    await _saveCloudEntry(
      nodeId: 'path_choice',
      score: 0,
      stars: 0,
      completedAt: chosenAt,
    );
    await _saveCloudEntry(
      nodeId: 'branch_$routeId',
      score: 0,
      stars: 0,
      completedAt: chosenAt,
    );
    return true;
  }

  Future<bool> completeNode(
    String nodeId, {
    required int score,
    int stars = 1,
  }) async {
    final node = campaign.node(nodeId);
    if (node.kind == SoloNodeKind.choice ||
        state.isComplete(nodeId) ||
        !state.isUnlocked(node)) {
      return false;
    }
    final entry = SoloProgressEntry(
      nodeId: nodeId,
      score: score.clamp(0, 100).toInt(),
      stars: stars.clamp(0, 3).toInt(),
      completedAt: DateTime.now().toUtc(),
    );
    final completed = {...state.completed, nodeId: entry};
    state = SoloJourneyState(
      completed: Map.unmodifiable(completed),
      selectedRoute: state.selectedRoute,
    );
    await _saveLocal();
    await _saveCloudEntry(
      nodeId: nodeId,
      score: entry.score,
      stars: entry.stars,
      completedAt: entry.completedAt,
    );
    return true;
  }

  Future<void> _saveCloudEntry({
    required String nodeId,
    required int score,
    required int stars,
    required DateTime completedAt,
  }) async {
    if (playerProfileId == null || !_cloudAvailable) return;
    try {
      await supabase.Supabase.instance.client
          .rpc(
            'complete_solo_node',
            params: {
              'p_campaign_id': campaign.id,
              'p_node_id': nodeId,
              'p_score': score,
              'p_stars': stars,
            },
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      _cloudAvailable = false;
      // Local state remains authoritative until the next successful sync.
    }
  }

  Future<void> _syncPendingCloud(Set<String> cloudNodeIds) async {
    if (playerProfileId == null) return;
    final pending = <SoloProgressEntry>[];
    for (final entry in state.completed.values) {
      if (cloudNodeIds.contains(entry.nodeId)) continue;
      pending.add(entry);
    }
    final branch = state.selectedRoute;
    final branchNode = branch == null ? null : 'branch_$branch';
    if (branchNode != null && !cloudNodeIds.contains(branchNode)) {
      pending.add(
        SoloProgressEntry(
          nodeId: branchNode,
          score: 0,
          stars: 0,
          completedAt: DateTime.now().toUtc(),
        ),
      );
    }
    if (pending.isEmpty) return;
    pending.sort(
      (left, right) => _cloudNodeOrder
          .indexOf(left.nodeId)
          .compareTo(_cloudNodeOrder.indexOf(right.nodeId)),
    );
    try {
      final client = supabase.Supabase.instance.client;
      for (final entry in pending) {
        await client
            .rpc(
              'complete_solo_node',
              params: {
                'p_campaign_id': campaign.id,
                'p_node_id': entry.nodeId,
                'p_score': entry.score,
                'p_stars': entry.stars,
              },
            )
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {
      _cloudAvailable = false;
      // Keep the local queue; the next successful load will retry it.
    }
  }

  Future<void> _saveLocal() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _storageKey,
        jsonEncode({
          'selected_route': state.selectedRoute,
          'completed': state.completed.values
              .map((entry) => entry.toLocalJson())
              .toList(),
        }),
      );
    } catch (_) {
      state = SoloJourneyState(
        completed: state.completed,
        selectedRoute: state.selectedRoute,
        error: 'No se pudo guardar el avance en este dispositivo.',
      );
    }
  }
}

final soloCampaignProvider = Provider<SoloCampaignDefinition>((ref) {
  final selection = ref.watch(
    authProvider.select(
      (state) => (
        state.user?['grade']?.toString(),
        state.user?['subject']?.toString(),
      ),
    ),
  );
  return SoloCampaignDefinition(
    grade: selection.$1 ?? 'Primaria',
    subject: selection.$2 ?? 'General',
  );
});

final soloJourneyProvider =
    StateNotifierProvider.autoDispose<SoloJourneyNotifier, SoloJourneyState>((
      ref,
    ) {
      final auth = ref.watch(authProvider);
      final campaign = ref.watch(soloCampaignProvider);
      final notifier = SoloJourneyNotifier(
        playerProfileId: auth.user?['player_profile_id']?.toString(),
        campaign: campaign,
        startOffline: auth.isOffline,
      );
      notifier.load();
      return notifier;
    });
