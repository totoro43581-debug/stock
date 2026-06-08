import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:stock/core/game_time/game_time_config.dart';
import 'package:stock/core/game_time/game_time_service.dart';

import '../../asset_account/repository/asset_account_repository.dart';
import '../model/coin_holding_model.dart';
import '../model/coin_item_model.dart';
import '../model/coin_trade_history_model.dart';

class CoinRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final AssetAccountRepository _assetAccountRepository =
  AssetAccountRepository();

  final GameTimeService _gameTimeService = const GameTimeService();

  static const double _coinTradeFeeRate = 0.001;

  // 수정45차: 소수점 오차 방어 기준
  static const double _quantityEpsilon = 0.00000001;

  // 수정53차: 코인 시장 변동 기준
  // 실제 초 단위 타이머가 아니라 게임 시간 기준으로 계산
  // 코인: 게임 시간 10분마다 1틱 변동
  static const int _coinMarketTickGameMinutes =
      GameTimeConfig.coinMarketTickGameMinutes;

  // 수정53차: 장시간 미접속 후 한 번에 과도하게 튀는 것 방지
  static const int _maxCatchUpTickCount = 60;

  Future<List<CoinItemModel>> fetchActiveCoins() async {
    await _simulateCoinMarketTickByElapsedGameTime();

    return _fetchActiveCoinsRaw();
  }

  Future<List<CoinItemModel>> _fetchActiveCoinsRaw() async {
    final response = await _client
        .from('coin_item')
        .select()
        .eq('is_active', true)
        .order('current_price', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map(CoinItemModel.fromMap)
        .toList();
  }

  Future<List<CoinHoldingModel>> fetchMyCoinHoldings() async {
    final User? user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await _client
        .from('coin_holding')
        .select()
        .eq('user_id', user.id)
        .gt('quantity', 0)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map(CoinHoldingModel.fromMap)
        .toList();
  }

  Future<List<CoinTradeHistoryModel>> fetchMyCoinTradeHistory() async {
    final User? user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await _client
        .from('coin_trade_history')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(100);

    return List<Map<String, dynamic>>.from(response)
        .map(CoinTradeHistoryModel.fromMap)
        .toList();
  }

  // 수정37차: 코인 투자 계좌 현금 조회
  Future<double> fetchCoinAccountCashBalance() async {
    return _assetAccountRepository.fetchAccountCashBalance(
      accountType: 'coin',
    );
  }

  // 수정53차: 화면이 꺼져 있어도 지난 게임 시간만큼 시세를 따라잡는 구조
  Future<void> _simulateCoinMarketTickByElapsedGameTime() async {
    final DateTime now = _gameTimeService.nowUtc();

    final Map<String, dynamic>? state = await _client
        .from('market_time_state')
        .select('last_tick_at')
        .eq('market_type', 'coin')
        .maybeSingle();

    if (state == null) {
      await _client.from('market_time_state').insert({
        'market_type': 'coin',
        'last_tick_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      return;
    }

    final DateTime lastTickAt =
        DateTime.tryParse(state['last_tick_at']?.toString() ?? '')?.toUtc() ??
            now;

    final int tickCount = _gameTimeService.elapsedMarketTickCount(
      fromUtc: lastTickAt,
      toUtc: now,
      marketGameMinuteInterval: _coinMarketTickGameMinutes,
      maxTickCount: _maxCatchUpTickCount,
    );

    if (tickCount <= 0) {
      return;
    }

    for (int i = 0; i < tickCount; i++) {
      await _simulateCoinMarketTickOnce();
    }

    await _client.from('market_time_state').upsert({
      'market_type': 'coin',
      'last_tick_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  // 수정53차: 화면 Timer에서 직접 호출해도 게임시간 상태를 갱신하는 강제 1틱 변동
  Future<void> simulateCoinMarketTick() async {
    final DateTime now = _gameTimeService.nowUtc();

    await _simulateCoinMarketTickOnce();

    await _client.from('market_time_state').upsert({
      'market_type': 'coin',
      'last_tick_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  // 수정51차: 코인 시세 1틱 변동 안정화
  Future<void> _simulateCoinMarketTickOnce() async {
    final List<CoinItemModel> coins = await _fetchActiveCoinsRaw();
    final Random random = Random();

    for (final coin in coins) {
      final double volatilityWeight = _coinVolatilityWeight(coin.currentPrice);

      final double direction = random.nextDouble() >= 0.5 ? 1 : -1;

      // 기본 변동폭: 0.12% ~ 0.72%
      final double baseMovePercent = 0.12 + random.nextDouble() * 0.6;

      // 급등락 확률: 7%
      final bool hasSpike = random.nextDouble() < 0.07;

      // 급등락 추가 변동폭: 최대 1.2%
      final double spikeMovePercent = hasSpike ? random.nextDouble() * 1.2 : 0;

      double movePercent =
          direction * (baseMovePercent + spikeMovePercent) * volatilityWeight;

      // 1틱 최대 변동 제한
      movePercent = movePercent.clamp(-2.2, 2.2).toDouble();

      final double moveRate = movePercent / 100;

      double nextPrice = coin.currentPrice * (1 + moveRate);

      if (nextPrice < 1) {
        nextPrice = 1;
      }

      nextPrice = _normalizeCoinPrice(nextPrice);

      final double nextChangeRate =
      (coin.changeRate + movePercent).clamp(-15.0, 15.0).toDouble();

      // 거래량은 가격 변동과 같이 움직이되 과도하게 튀지 않게 제한
      final double volumeMoveWeight = 0.96 + random.nextDouble() * 0.12;
      final double volumeSpikeWeight =
      hasSpike ? 1.05 + random.nextDouble() * 0.12 : 1.0;

      double nextTradeVolume =
          coin.tradeVolume * volumeMoveWeight * volumeSpikeWeight;

      if (nextTradeVolume < 1) {
        nextTradeVolume = 1;
      }

      await _client.from('coin_item').update({
        'current_price': nextPrice,
        'change_rate': nextChangeRate,
        'trade_volume': nextTradeVolume,
      }).eq('code', coin.code);

      await _client.from('coin_price_history').insert({
        'coin_code': coin.code,
        'coin_name': coin.name,
        'price': nextPrice,
        'change_rate': nextChangeRate,
        'trade_volume': nextTradeVolume,
      });
    }
  }

  // 수정45차: 코인 매수 안정화
  Future<void> buyCoin({
    required CoinItemModel coin,
    required double quantity,
  }) async {
    final User? user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    if (quantity <= 0) {
      throw Exception('매수 수량을 입력해주세요.');
    }

    final double tradePrice = coin.currentPrice;

    if (tradePrice <= 0) {
      throw Exception('현재가가 올바르지 않습니다.');
    }

    final double rawAmount = tradePrice * quantity;
    final double fee = rawAmount * _coinTradeFeeRate;
    final double totalAmount = rawAmount + fee;

    if (totalAmount <= 0) {
      throw Exception('주문금액이 올바르지 않습니다.');
    }

    final double latestCoinCash =
    await _assetAccountRepository.fetchAccountCashBalance(
      accountType: 'coin',
    );

    if (latestCoinCash + 0.0001 < totalAmount) {
      throw Exception(
        '코인 투자 계좌 잔액이 부족합니다. 필요금액: ${_formatMoney(totalAmount)}원',
      );
    }

    final double coinCashAfterBuy = latestCoinCash - totalAmount;

    final Map<String, dynamic>? currentHolding = await _client
        .from('coin_holding')
        .select()
        .eq('user_id', user.id)
        .eq('coin_code', coin.code)
        .maybeSingle();

    if (currentHolding == null) {
      await _client.from('coin_holding').insert({
        'user_id': user.id,
        'coin_code': coin.code,
        'coin_name': coin.name,
        'quantity': quantity,
        'average_price': tradePrice,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } else {
      final double currentQuantity = _toDouble(currentHolding['quantity']);
      final double currentAveragePrice =
      _toDouble(currentHolding['average_price']);

      final double currentTotal = currentQuantity * currentAveragePrice;
      final double addedTotal = quantity * tradePrice;
      final double nextQuantity = currentQuantity + quantity;
      final double nextAveragePrice =
      nextQuantity <= 0 ? 0 : (currentTotal + addedTotal) / nextQuantity;

      await _client
          .from('coin_holding')
          .update({
        'quantity': nextQuantity,
        'average_price': nextAveragePrice,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('user_id', user.id)
          .eq('coin_code', coin.code);
    }

    await _assetAccountRepository.updateAccountCashBalance(
      accountType: 'coin',
      cashBalance: coinCashAfterBuy,
    );

    await _client.from('coin_trade_history').insert({
      'user_id': user.id,
      'coin_code': coin.code,
      'coin_name': coin.name,
      'trade_type': 'buy',
      'trade_price': tradePrice,
      'quantity': quantity,
      'total_amount': rawAmount,
      'fee': fee,
    });

    await _assetAccountRepository.addAssetAccountTransaction(
      type: 'withdraw',
      reason: 'coin_buy',
      amount: totalAmount,
      balanceAfter: coinCashAfterBuy,
      title: '${coin.name} 매수',
      memo:
      '${coin.name} ${_formatQuantity(quantity)}개 · 수수료 ${_formatMoney(fee)}원',
    );
  }

  // 수정45차: 코인 매도 안정화
  Future<void> sellCoin({
    required CoinItemModel coin,
    required double quantity,
  }) async {
    final User? user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    if (quantity <= 0) {
      throw Exception('매도 수량을 입력해주세요.');
    }

    final double tradePrice = coin.currentPrice;

    if (tradePrice <= 0) {
      throw Exception('현재가가 올바르지 않습니다.');
    }

    final Map<String, dynamic>? currentHolding = await _client
        .from('coin_holding')
        .select()
        .eq('user_id', user.id)
        .eq('coin_code', coin.code)
        .maybeSingle();

    if (currentHolding == null) {
      throw Exception('보유 중인 코인이 없습니다.');
    }

    final double currentQuantity = _toDouble(currentHolding['quantity']);

    if (currentQuantity <= 0) {
      await _client
          .from('coin_holding')
          .delete()
          .eq('user_id', user.id)
          .eq('coin_code', coin.code);

      throw Exception('보유 중인 코인이 없습니다.');
    }

    if (currentQuantity + _quantityEpsilon < quantity) {
      throw Exception(
        '보유 수량이 부족합니다. 보유수량: ${_formatQuantity(currentQuantity)}개',
      );
    }

    final double safeQuantity =
    quantity > currentQuantity ? currentQuantity : quantity;

    final double rawAmount = tradePrice * safeQuantity;
    final double fee = rawAmount * _coinTradeFeeRate;
    final double receiveAmount = rawAmount - fee;

    if (receiveAmount <= 0) {
      throw Exception('매도 금액이 올바르지 않습니다.');
    }

    final double latestCoinCash =
    await _assetAccountRepository.fetchAccountCashBalance(
      accountType: 'coin',
    );

    final double coinCashAfterSell = latestCoinCash + receiveAmount;
    final double nextQuantity = currentQuantity - safeQuantity;

    if (nextQuantity <= _quantityEpsilon) {
      await _client
          .from('coin_holding')
          .delete()
          .eq('user_id', user.id)
          .eq('coin_code', coin.code);
    } else {
      await _client
          .from('coin_holding')
          .update({
        'quantity': nextQuantity,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('user_id', user.id)
          .eq('coin_code', coin.code);
    }

    await _assetAccountRepository.updateAccountCashBalance(
      accountType: 'coin',
      cashBalance: coinCashAfterSell,
    );

    await _client.from('coin_trade_history').insert({
      'user_id': user.id,
      'coin_code': coin.code,
      'coin_name': coin.name,
      'trade_type': 'sell',
      'trade_price': tradePrice,
      'quantity': safeQuantity,
      'total_amount': rawAmount,
      'fee': fee,
    });

    await _assetAccountRepository.addAssetAccountTransaction(
      type: 'deposit',
      reason: 'coin_sell',
      amount: receiveAmount,
      balanceAfter: coinCashAfterSell,
      title: '${coin.name} 매도',
      memo:
      '${coin.name} ${_formatQuantity(safeQuantity)}개 · 수수료 ${_formatMoney(fee)}원',
    );
  }

  double _coinVolatilityWeight(double price) {
    if (price >= 1000000) {
      return 0.7;
    }

    if (price >= 100000) {
      return 0.85;
    }

    if (price >= 10000) {
      return 1.0;
    }

    if (price >= 1000) {
      return 1.15;
    }

    if (price >= 100) {
      return 1.35;
    }

    return 1.6;
  }

  double _normalizeCoinPrice(double value) {
    if (value >= 1000) {
      return value.roundToDouble();
    }

    if (value >= 100) {
      return double.parse(value.toStringAsFixed(1));
    }

    return double.parse(value.toStringAsFixed(2));
  }

  String _formatQuantity(double value) {
    if (value >= 1) {
      return value.toStringAsFixed(4);
    }

    return value.toStringAsFixed(6);
  }

  String _formatMoney(double value) {
    return value.round().toString();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}