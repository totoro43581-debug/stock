import 'game_time_config.dart';

class GameClockSnapshot {
  final DateTime gameTimeUtc;
  final DateTime receivedAtUtc;
  final double speed;

  const GameClockSnapshot({
    required this.gameTimeUtc,
    required this.receivedAtUtc,
    required this.speed,
  });

  factory GameClockSnapshot.fromMap(
    Map<String, dynamic> data, {
    DateTime? receivedAtUtc,
  }) {
    final time = DateTime.tryParse(data['game_datetime']?.toString() ?? '');
    final speed = double.tryParse(
      data['game_seconds_per_real_second']?.toString() ?? '',
    );
    if (time == null || speed == null || !speed.isFinite || speed <= 0) {
      throw const FormatException('게임 시간 응답이 올바르지 않습니다.');
    }
    return GameClockSnapshot(
      gameTimeUtc: time.toUtc(),
      receivedAtUtc: (receivedAtUtc ?? DateTime.now()).toUtc(),
      speed: speed,
    );
  }

  DateTime at(DateTime realTime) {
    final elapsed = realTime.toUtc().difference(receivedAtUtc).inMicroseconds;
    return gameTimeUtc.add(
      Duration(microseconds: ((elapsed < 0 ? 0 : elapsed) * speed).round()),
    );
  }
}

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
