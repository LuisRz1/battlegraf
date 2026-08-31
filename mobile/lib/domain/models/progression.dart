class ProgressionProfile {
  final int xp;
  final String? rankName;
  final String? clanName;

  const ProgressionProfile({required this.xp, this.rankName, this.clanName});

  factory ProgressionProfile.fromJson(Map<String, dynamic> json) {
    final rank = json['rank'] as Map<String, dynamic>?;
    final clan = json['clan'] as Map<String, dynamic>?;
    return ProgressionProfile(
      xp: json['xp'] as int? ?? 0,
      rankName: rank?['name']?.toString(),
      clanName: clan?['name']?.toString(),
    );
  }
}

class LeaderboardEntry {
  final int position;
  final String userId;
  final String displayName;
  final int xp;

  const LeaderboardEntry({
    required this.position,
    required this.userId,
    required this.displayName,
    required this.xp,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      position: json['position'] as int,
      userId: json['user_id'].toString(),
      displayName: json['display_name'].toString(),
      xp: json['xp'] as int? ?? 0,
    );
  }
}
