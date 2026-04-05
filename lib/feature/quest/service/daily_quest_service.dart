import 'package:stock/feature/quest/repository/daily_quest_repository.dart';

class DailyQuestService {
  DailyQuestService();

  final DailyQuestRepository _repository = DailyQuestRepository();

  Future<void> completeAttendanceQuest() async {
    await _repository.completeQuest('attendance');
  }

  Future<void> completeOpenMarketQuest() async {
    await _repository.completeQuest('open_market');
  }

  Future<void> completeCheckWalletQuest() async {
    await _repository.completeQuest('check_wallet');
  }
}