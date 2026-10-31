import 'package:flutter_test/flutter_test.dart';
import 'package:stock/core/game_time/game_time_service.dart';
import 'package:stock/feature/bank/model/user_bank_account_model.dart';

void main() {
  final realNow = DateTime.utc(2026, 10, 29);
  final gameNow = DateTime.utc(2026, 1, 30);

  UserBankAccountModel account({
    String? timeModel,
    bool savings = false,
    int paid = 1,
    DateTime? maturity,
  }) => UserBankAccountModel.fromMap({
    'product_type': savings ? 'savings' : 'deposit',
    'status': 'active',
    'start_at': gameNow.toIso8601String(),
    'maturity_at': (maturity ?? gameNow.add(const Duration(days: 3)))
        .toIso8601String(),
    'paid_installments': paid,
    'total_installments': savings ? 4 : null,
    'time_model': ?timeModel,
  });

  test('game time advances at the server-provided speed', () {
    final snapshot = GameClockSnapshot.fromMap({
      'game_datetime': gameNow.toIso8601String(),
      'game_seconds_per_real_second': 6,
    }, receivedAtUtc: realNow);
    expect(
      snapshot.at(realNow.add(const Duration(hours: 4))),
      gameNow.add(const Duration(days: 1)),
    );
    expect(snapshot.at(realNow.subtract(const Duration(hours: 1))), gameNow);
  });

  test('an invalid clock never invents a date or speed', () {
    for (final speed in [null, 0, -1, 'NaN', 'Infinity']) {
      expect(
        () => GameClockSnapshot.fromMap({
          'game_datetime': gameNow.toIso8601String(),
          'game_seconds_per_real_second': speed,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => GameClockSnapshot.fromMap({
        'game_datetime': 'invalid',
        'game_seconds_per_real_second': 6,
      }),
      throwsFormatException,
    );
  });

  test('a virtual account cannot mature just because real time is later', () {
    final item = account(timeModel: 'virtual');
    expect(item.maturedAt(realNow: realNow, gameNow: gameNow), isFalse);
    expect(item.maturedAt(realNow: realNow), isFalse);
    expect(
      item.maturedAt(
        realNow: realNow,
        gameNow: gameNow.add(const Duration(days: 3)),
      ),
      isTrue,
    );
  });

  test('old responses without a time model keep real-time maturity', () {
    final item = account(maturity: realNow.add(const Duration(days: 1)));
    expect(item.usesGameTime, isFalse);
    expect(
      item.maturedAt(realNow: realNow, gameNow: DateTime.utc(2050)),
      isFalse,
    );
    expect(
      item.maturedAt(realNow: realNow.add(const Duration(days: 1))),
      isTrue,
    );
  });

  test('full savings payout requires all installments', () {
    expect(
      UserBankAccountModel.fromMap({
        'product_type': 'savings',
        'time_model': 'virtual',
      }).installmentsComplete,
      isFalse,
    );
    expect(
      account(
        timeModel: 'virtual',
        savings: true,
        paid: 3,
      ).installmentsComplete,
      isFalse,
    );
    expect(
      account(
        timeModel: 'virtual',
        savings: true,
        paid: 4,
      ).installmentsComplete,
      isTrue,
    );
    expect(account(timeModel: 'virtual').installmentsComplete, isTrue);
  });
}
