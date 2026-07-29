import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../domain/models/progression.dart';
import 'auth_provider.dart';

class ProgressionState {
  final ProgressionProfile? profile;
  final List<LeaderboardEntry> leaderboard;
  final bool isLoading;
  final String? error;

  const ProgressionState({
    this.profile,
    this.leaderboard = const [],
    this.isLoading = false,
    this.error,
  });

  ProgressionState copyWith({
    ProgressionProfile? profile,
    List<LeaderboardEntry>? leaderboard,
    bool? isLoading,
    String? error,
  }) {
    return ProgressionState(
      profile: profile ?? this.profile,
      leaderboard: leaderboard ?? this.leaderboard,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProgressionNotifier extends StateNotifier<ProgressionState> {
  final ApiClient apiClient;
  final String? sectionId;

  ProgressionNotifier(this.apiClient, this.sectionId)
    : super(const ProgressionState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profileResponse = await apiClient.dio.get('/progression/me');
      final leaderboardResponse = sectionId == null
          ? null
          : await apiClient.dio.get(
              '/progression/leaderboards/section/$sectionId',
            );
      state = state.copyWith(
        isLoading: false,
        profile: ProgressionProfile.fromJson(
          profileResponse.data as Map<String, dynamic>,
        ),
        leaderboard: leaderboardResponse == null
            ? const []
            : (leaderboardResponse.data as List<dynamic>)
                  .map(
                    (item) =>
                        LeaderboardEntry.fromJson(item as Map<String, dynamic>),
                  )
                  .toList(),
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: _message(error));
    }
  }

  String _message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['detail'] != null) {
        return data['detail'].toString();
      }
    }
    return 'No se pudo cargar la progresion.';
  }
}

final progressionProvider =
    StateNotifierProvider<ProgressionNotifier, ProgressionState>((ref) {
      final auth = ref.watch(authProvider);
      return ProgressionNotifier(
        ApiClient(token: auth.token),
        auth.user?['section_id']?.toString(),
      );
    });
