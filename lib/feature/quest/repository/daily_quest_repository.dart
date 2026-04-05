import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/quest/model/daily_quest_model.dart';

class DailyQuestRepository {
  DailyQuestRepository();

  final SupabaseClient _client = Supabase.instance.client;

  String _todayString() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> ensureTodayQuests() async {
    await _client.rpc('ensure_today_daily_quests');
  }

  Future<List<DailyQuestModel>> fetchTodayQuests() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    await ensureTodayQuests();

    final data = await _client
        .from('user_daily_quests')
        .select('''
          quest_code,
          is_completed,
          completed_at,
          is_claimed,
          claimed_at,
          daily_quest_master (
            title,
            description,
            reward_amount,
            sort_order
          )
        ''')
        .eq('user_id', user.id)
        .eq('quest_date', _todayString());

    final list = (data as List)
        .map((e) => DailyQuestModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  Future<void> completeQuest(String questCode) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    await ensureTodayQuests();

    await _client
        .from('user_daily_quests')
        .update({
      'is_completed': true,
      'completed_at': DateTime.now().toIso8601String(),
    })
        .eq('user_id', user.id)
        .eq('quest_code', questCode)
        .eq('quest_date', _todayString());
  }

  Future<Map<String, dynamic>> claimQuest(String questCode) async {
    final result = await _client.rpc(
      'claim_daily_quest_reward',
      params: {
        'p_quest_code': questCode,
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }
}