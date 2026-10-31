import 'package:flutter_test/flutter_test.dart';
import 'package:stock/core/game_time/game_time_service.dart';

void main() {
  GameClockMapping mapping([double speed = 6]) => GameClockMapping.fromMap({
    'real_epoch': '2026-01-01T00:00:00Z',
    'virtual_epoch': '2025-12-31T15:00:00Z',
    'game_seconds_per_real_second': speed,
  });

  test('three game days map to twelve real hours, not three real days', () {
    expect(mapping().realTimeForGameDay(3), DateTime.utc(2026, 1, 1, 12));
    expect(mapping().realTimeForGameDay(0), DateTime.utc(2026, 1, 1));
    expect(() => mapping().realTimeForGameDay(-1), throwsRangeError);
  });

  test(
    'virtual deposit timestamps and day-based loans use the same mapping',
    () {
      final clock = mapping();
      expect(
        clock.realTimeForGameTime(DateTime.parse('2026-01-03T15:00:00Z')),
        clock.realTimeForGameDay(3),
      );
    },
  );

  test('display conversion follows the supplied speed and subday time', () {
    expect(mapping(12).realTimeForGameDay(3), DateTime.utc(2026, 1, 1, 6));
    expect(
      mapping().realTimeForGameTime(DateTime.parse('2025-12-31T15:00:06Z')),
      DateTime.utc(2026, 1, 1, 0, 0, 1),
    );
  });

  test('missing epoch and invalid speeds cannot invent a deadline', () {
    expect(
      () => GameClockMapping.fromMap({'game_seconds_per_real_second': 6}),
      throwsFormatException,
    );
    for (final speed in [0.0, -1.0, double.infinity, double.nan]) {
      expect(() => mapping(speed), throwsFormatException);
    }
    expect(realDeadlineLabel(null), '예정 시각 확인 불가');
  });

  test(
    'Korea time crosses month boundary independently of system timezone',
    () {
      expect(
        realDeadlineLabel(DateTime.utc(2026, 10, 31, 18), showRemaining: false),
        '2026.11.01 오전 3:00:00',
      );
      expect(
        realDeadlineLabel(DateTime.utc(2026, 1, 1, 3), showRemaining: false),
        '2026.01.01 오후 12:00:00',
      );
      expect(
        realDeadlineLabel(DateTime.utc(2025, 12, 31, 15), showRemaining: false),
        '2026.01.01 오전 12:00:00',
      );
    },
  );

  test(
    'remaining labels distinguish a future time from an elapsed estimate',
    () {
      final now = DateTime.utc(2026, 1, 1);
      expect(
        realDeadlineLabel(now.add(const Duration(hours: 12)), now: now),
        endsWith('약 12시간 0분 남음'),
      );
      expect(
        realDeadlineLabel(now.add(const Duration(seconds: 59)), now: now),
        endsWith('약 59초 남음'),
      );
      expect(realDeadlineLabel(now, now: now), endsWith('예정 시각 경과'));
    },
  );
}
