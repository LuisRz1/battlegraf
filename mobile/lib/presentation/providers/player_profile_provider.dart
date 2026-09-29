import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'dart:convert';

import 'auth_provider.dart';
import 'solo_journey_provider.dart';

class PlayerProfileState {
  const PlayerProfileState({
    this.isLoading = false,
    this.error,
    this.profile = const {},
    this.catalog = const [],
    this.ownedItems = const {},
  });

  final bool isLoading;
  final String? error;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> catalog;
  final Set<String> ownedItems;

  Map<String, dynamic> get avatarConfig =>
      Map<String, dynamic>.from(profile['avatar_config'] as Map? ?? const {});

  String get displayName => profile['display_name']?.toString() ?? 'Explorador';
  String get grade => profile['grade']?.toString() ?? '5to de primaria';
  String get subject => profile['subject']?.toString() ?? 'General';

  List<Map<String, dynamic>> itemsForSlot(String slot) =>
      catalog.where((item) => item['slot'] == slot).toList(growable: false);
}

class PlayerProfileNotifier extends StateNotifier<PlayerProfileState> {
  PlayerProfileNotifier(this.ref) : super(const PlayerProfileState());

  final Ref ref;

  static const _offlineAvatarPrefix = 'battlegraf.avatar.equipped';

  static const _fallbackCatalog = <Map<String, dynamic>>[
    {
      'item_key': 'portrait_nova',
      'slot': 'portrait',
      'display_name': 'Nova',
      'asset_key': 'avatar/portrait_nova',
      'rarity': 'common',
      'required_completed_nodes': 0,
    },
    {
      'item_key': 'portrait_terra',
      'slot': 'portrait',
      'display_name': 'Terra',
      'asset_key': 'avatar/portrait_terra',
      'rarity': 'uncommon',
      'required_completed_nodes': 4,
    },
    {
      'item_key': 'background_sky',
      'slot': 'background',
      'display_name': 'Cielo',
      'asset_key': 'avatar/background_sky',
      'rarity': 'common',
      'required_completed_nodes': 0,
    },
    {
      'item_key': 'background_nebula',
      'slot': 'background',
      'display_name': 'Nebulosa',
      'asset_key': 'avatar/background_nebula',
      'rarity': 'rare',
      'required_completed_nodes': 8,
    },
    {
      'item_key': 'frame_copper',
      'slot': 'frame',
      'display_name': 'Cobre',
      'asset_key': 'avatar/frame_copper',
      'rarity': 'common',
      'required_completed_nodes': 3,
    },
    {
      'item_key': 'frame_prism',
      'slot': 'frame',
      'display_name': 'Prisma',
      'asset_key': 'avatar/frame_prism',
      'rarity': 'epic',
      'required_completed_nodes': 12,
    },
    {
      'item_key': 'effect_spark',
      'slot': 'effect',
      'display_name': 'Chispa',
      'asset_key': 'avatar/effect_spark',
      'rarity': 'uncommon',
      'required_completed_nodes': 5,
    },
    {
      'item_key': 'accessory_comet',
      'slot': 'accessory',
      'display_name': 'Cometa',
      'asset_key': 'avatar/accessory_comet',
      'rarity': 'rare',
      'required_completed_nodes': 10,
    },
  ];

  Future<void> load() async {
    final auth = ref.read(authProvider);
    final authUser = auth.user;
    final playerId = authUser?['player_profile_id']?.toString();
    if (playerId == null || playerId.isEmpty || auth.isOffline) {
      final profile = Map<String, dynamic>.from(
        authUser?['player_profile'] as Map? ?? const {},
      );
      final localEquipped = Map<String, dynamic>.from(
        profile['avatar_config'] as Map? ?? const {},
      );
      state = PlayerProfileState(
        profile: profile,
        catalog: _fallbackCatalog,
        ownedItems: {
          'portrait_nova',
          'background_sky',
          ...localEquipped.values.map((value) => '$value'),
        },
      );
      return;
    }

    state = PlayerProfileState(
      isLoading: true,
      profile: state.profile,
      catalog: state.catalog,
      ownedItems: state.ownedItems,
    );
    try {
      final client = supabase.Supabase.instance.client;
      final preferences = await SharedPreferences.getInstance();
      final pendingKey = 'battlegraf.player.pending.$playerId';
      final pendingProfile = preferences.getString(pendingKey);
      if (pendingProfile != null) {
        final decoded = jsonDecode(pendingProfile);
        if (decoded is Map) {
          final patch = Map<String, dynamic>.from(decoded)
            ..remove('avatar_config');
          if (patch.isNotEmpty) {
            await client
                .from('player_profiles')
                .update(patch)
                .eq('id', playerId);
          }
          await preferences.remove(pendingKey);
        }
      }
      final profile = Map<String, dynamic>.from(
        await client
            .from('player_profiles')
            .select(
              'id, display_name, grade, subject, preferred_mode, avatar_config',
            )
            .eq('id', playerId)
            .single()
            .timeout(const Duration(seconds: 4)),
      );
      await client
          .rpc('award_player_cosmetics')
          .timeout(const Duration(seconds: 4));
      final catalogRows = await client
          .from('avatar_catalog')
          .select(
            'item_key, slot, display_name, asset_key, rarity, required_completed_nodes',
          )
          .eq('is_active', true)
          .order('required_completed_nodes')
          .timeout(const Duration(seconds: 4));
      final ownershipRows = await client
          .from('player_cosmetics')
          .select('item_key')
          .eq('player_profile_id', playerId)
          .timeout(const Duration(seconds: 4));
      final pendingBySlot = <String, String>{};
      final ownedRows = List<Map<String, dynamic>>.from(ownershipRows);
      for (final item in List<Map<String, dynamic>>.from(catalogRows)) {
        final slot = '${item['slot']}';
        final pending = preferences.getString(
          '$_offlineAvatarPrefix.$playerId.$slot',
        );
        if (pending != null &&
            ownedRows.any((owned) => '${owned['item_key']}' == pending)) {
          pendingBySlot[slot] = pending;
        }
      }
      for (final itemKey in pendingBySlot.values) {
        await client.rpc(
          'equip_player_cosmetic',
          params: {'p_item_key': itemKey},
        );
      }
      final refreshedProfile = pendingBySlot.isEmpty
          ? profile
          : Map<String, dynamic>.from(
              await client
                  .from('player_profiles')
                  .select(
                    'id, display_name, grade, subject, preferred_mode, avatar_config',
                  )
                  .eq('id', playerId)
                  .single()
                  .timeout(const Duration(seconds: 4)),
            );
      state = PlayerProfileState(
        profile: refreshedProfile,
        catalog: List<Map<String, dynamic>>.from(catalogRows),
        ownedItems: {
          for (final row in List<Map<String, dynamic>>.from(ownershipRows))
            '${row['item_key']}',
        },
      );
      await ref
          .read(authProvider.notifier)
          .syncPlayerProfileSnapshot(refreshedProfile);
    } catch (error) {
      state = PlayerProfileState(
        profile: Map<String, dynamic>.from(
          authUser?['player_profile'] as Map? ?? state.profile,
        ),
        catalog: state.catalog.isEmpty ? _fallbackCatalog : state.catalog,
        ownedItems: state.ownedItems,
        error: 'No se pudo sincronizar el perfil del jugador: $error',
      );
    }
  }

  Future<bool> updatePreferences({String? grade, String? subject}) async {
    final playerId = state.profile['id']?.toString();
    if (playerId == null) return false;
    final patch = <String, dynamic>{};
    if (grade != null) patch['grade'] = grade;
    if (subject != null) patch['subject'] = subject;
    if (patch.isEmpty) return true;
    try {
      if (ref.read(authProvider).isOffline) {
        return await _cachePendingProfilePatch(patch);
      }
      await supabase.Supabase.instance.client
          .from('player_profiles')
          .update(patch)
          .eq('id', playerId)
          .timeout(const Duration(seconds: 4));
      await load();
      return true;
    } catch (_) {
      return await _cachePendingProfilePatch(patch);
    }
  }

  Future<bool> equip(String itemKey) async {
    final item = state.catalog.firstWhere(
      (entry) => '${entry['item_key']}' == itemKey,
      orElse: () => const <String, dynamic>{},
    );
    if (item.isEmpty) return false;
    final offline = ref.read(authProvider).isOffline;
    final threshold = (item['required_completed_nodes'] as num?)?.toInt() ?? 0;
    final earnedByProgress =
        ref.read(soloJourneyProvider).completedCount >= threshold;
    if (!state.ownedItems.contains(itemKey) && !earnedByProgress) return false;
    try {
      final slot = '${item['slot']}';
      if (offline || !state.ownedItems.contains(itemKey)) {
        return await _cachePendingCosmetic(itemKey, slot);
      }
      final avatarConfig = await supabase.Supabase.instance.client
          .rpc('equip_player_cosmetic', params: {'p_item_key': itemKey})
          .timeout(const Duration(seconds: 4));
      state = PlayerProfileState(
        profile: {...state.profile, 'avatar_config': avatarConfig},
        catalog: state.catalog,
        ownedItems: state.ownedItems,
      );
      await ref
          .read(authProvider.notifier)
          .syncPlayerProfileSnapshot(state.profile);
      return true;
    } catch (_) {
      return await _cachePendingCosmetic(itemKey, '${item['slot']}');
    }
  }

  Future<bool> _cachePendingProfilePatch(Map<String, dynamic> patch) async {
    final playerId = state.profile['id']?.toString();
    if (playerId == null) return false;
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = 'battlegraf.player.pending.$playerId';
      final existing = preferences.getString(key);
      final pending = existing == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(existing) as Map);
      pending.addAll(patch);
      await preferences.setString(key, jsonEncode(pending));
      state = PlayerProfileState(
        profile: {...state.profile, ...patch},
        catalog: state.catalog,
        ownedItems: state.ownedItems,
        error: 'Se sincronizará cuando vuelva la conexión.',
      );
      await ref.read(authProvider.notifier).cachePlayerProfilePatch(patch);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _cachePendingCosmetic(String itemKey, String slot) async {
    final playerId = state.profile['id']?.toString();
    if (playerId == null) return false;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        '$_offlineAvatarPrefix.$playerId.$slot',
        itemKey,
      );
      final config = {...state.avatarConfig, slot: itemKey};
      state = PlayerProfileState(
        profile: {...state.profile, 'avatar_config': config},
        catalog: state.catalog,
        ownedItems: {...state.ownedItems, itemKey},
        error: 'Se sincronizará cuando vuelva la conexión.',
      );
      await ref.read(authProvider.notifier).cachePlayerProfilePatch({
        'avatar_config': config,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

final playerProfileProvider =
    StateNotifierProvider.autoDispose<
      PlayerProfileNotifier,
      PlayerProfileState
    >((ref) {
      final notifier = PlayerProfileNotifier(ref)..load();
      return notifier;
    });
