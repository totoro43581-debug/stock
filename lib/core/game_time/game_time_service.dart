import 'game_time_config.dart';

/// Uses the same epoch/rate equation as get_game_clock, without a client-clock anchor.
class GameClockMapping {
  final DateTime realEpochUtc;
  final DateTime virtualEpochUtc;
  final double speed;

  const GameClockMapping({
    required this.realEpochUtc,
    required this.virtualEpochUtc,
    required this.speed,
  });

  factory GameClockMapping.fromMap(Map<String, dynamic> data) {
    final real = DateTime.tryParse(data['real_epoch']?.toString() ?? '');
    final virtual = DateTime.tryParse(data['virtual_epoch']?.toString() ?? '');
    final speed = double.tryParse(
      data['game_seconds_per_real_second']?.toString() ?? '',
    );
    if (real == null ||
        virtual == null ||
        speed == null ||
        !speed.isFinite ||
        speed <= 0) {
      throw const FormatException('게임 시간 환산 기준을 확인할 수 없습니다.');
    }
    return GameClockMapping(
      realEpochUtc: real.toUtc(),
      virtualEpochUtc: virtual.toUtc(),
      speed: speed,
    );
  }

  DateTime realTimeForGameTime(DateTime gameTime) {
    final elapsed = gameTime.toUtc().difference(virtualEpochUtc).inMicroseconds;
    return realEpochUtc.add(Duration(microseconds: (elapsed / speed).round()));
  }

  DateTime realTimeForGameDay(int day) {
    if (day < 0) throw RangeError.value(day, 'day');
    return realTimeForGameTime(virtualEpochUtc.add(Duration(days: day)));
  }
}

/// Financial deadlines are displayed in Korea time, regardless of browser timezone.
String realDeadlineLabel(
  DateTime? deadline, {
  DateTime? now,
  bool showRemaining = true,
}) {
  if (deadline == null) return '예정 시각 확인 불가';
  final korea = deadline.toUtc().add(const Duration(hours: 9));
  String two(int value) => value.toString().padLeft(2, '0');
  final hour = korea.hour % 12 == 0 ? 12 : korea.hour % 12;
  final date =
      '${korea.year}.${two(korea.month)}.${two(korea.day)} '
      '${korea.hour < 12 ? '오전' : '오후'} $hour:${two(korea.minute)}:${two(korea.second)}';
  if (!showRemaining) return date;
  final seconds =
      deadline
          .toUtc()
          .difference((now ?? DateTime.now()).toUtc())
          .inMicroseconds /
      1000000;
  if (seconds <= 0) return '$date\n예정 시각 경과';
  if (seconds < 60) return '$date\n약 ${seconds.ceil()}초 남음';
  final minutes = (seconds / 60).ceil();
  final days = minutes ~/ 1440;
  final hours = (minutes % 1440) ~/ 60;
  final rest = minutes % 60;
  final remaining = days > 0
      ? '$days일 $hours시간'
      : hours > 0
      ? '$hours시간 $rest분'
      : '$minutes분';
  return '$date\n약 $remaining 남음';
}

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

  int elapsedGameMinutes({required DateTime fromUtc, DateTime? toUtc}) {
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

    final int gameMinutes = elapsedGameMinutes(fromUtc: fromUtc, toUtc: toUtc);

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
