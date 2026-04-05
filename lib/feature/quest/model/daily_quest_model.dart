class DailyQuestModel {
  final String code;
  final String title;
  final String description;
  final int rewardAmount;
  final int sortOrder;
  final bool isCompleted;
  final bool isClaimed;
  final DateTime? completedAt;
  final DateTime? claimedAt;

  const DailyQuestModel({
    required this.code,
    required this.title,
    required this.description,
    required this.rewardAmount,
    required this.sortOrder,
    required this.isCompleted,
    required this.isClaimed,
    required this.completedAt,
    required this.claimedAt,
  });

  factory DailyQuestModel.fromMap(Map<String, dynamic> map) {
    final master = Map<String, dynamic>.from(
      map['daily_quest_master'] as Map,
    );

    return DailyQuestModel(
      code: map['quest_code'] as String,
      title: master['title'] as String? ?? '',
      description: master['description'] as String? ?? '',
      rewardAmount: (master['reward_amount'] as num?)?.toInt() ?? 0,
      sortOrder: (master['sort_order'] as num?)?.toInt() ?? 0,
      isCompleted: map['is_completed'] as bool? ?? false,
      isClaimed: map['is_claimed'] as bool? ?? false,
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.parse(map['completed_at'] as String),
      claimedAt: map['claimed_at'] == null
          ? null
          : DateTime.parse(map['claimed_at'] as String),
    );
  }
}