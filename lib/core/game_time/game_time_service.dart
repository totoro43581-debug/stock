import 'game_time_config.dart';

class GameTimeService {
  const GameTimeService();

  DateTime nowUtc() {
    return DateTime.now().toUtc();
  }

  int elapsedGameMinutes({
    required DateTime fromUtc,
    DateTime? toUtc,
  }) {
    final DateTime start = fromUtc.toUtc();
    final DateTime end = (toUtc ?? nowUtc()).toUtc();

    if (end.isBefore(start)) {
      return 0;
    }

    final int elapsedRealSeconds = end.difference(start).inSeconds;

    return elapsedRealSeconds ~/ GameTimeConfig.realSecondsPerGameMinute;
  }

  int elapsedMarketTickCount({
    required DateTime fromUtc,
    DateTime? toUtc,
    required int marketGameMinuteInterval,
    int? maxTickCount,
  }) {
    if (marketGameMinuteInterval <= 0) {
      return 0;
    }

    final int gameMinutes = elapsedGameMinutes(
      fromUtc: fromUtc,
      toUtc: toUtc,
    );

    final int rawTickCount = gameMinutes ~/ marketGameMinuteInterval;

    if (maxTickCount == null) {
      return rawTickCount;
    }

    if (rawTickCount > maxTickCount) {
      return maxTickCount;
    }

    return rawTickCount;
  }
}