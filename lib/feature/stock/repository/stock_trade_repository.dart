import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:stock/feature/stock/model/stock_holding_model.dart';
import 'package:stock/feature/stock/model/stock_pending_order_model.dart';
import 'package:stock/feature/stock/model/stock_trade_history_model.dart';

class StockTradeRepository {
  StockTradeRepository();

  final SupabaseClient _client = Supabase.instance.client;

  // 주식 매수 수수료 없음
  static const double _stockBuyFeeRate = 0.0;

  // 주식 매도 수수료 0.15%
  static const double _stockSellFeeRate = 0.0015;

  Future<List<StockHoldingModel>> fetchHoldings(
      String userId,
      ) async {
    final data = await _client
        .from('stock_holdings')
        .select()
        .eq('user_id', userId)
        .gt('quantity', 0)
        .order('stock_name', ascending: true);

    return (data as List)
        .map(
          (e) => StockHoldingModel.fromMap(
        Map<String, dynamic>.from(e),
      ),
    )
        .toList();
  }

  Future<List<StockTradeHistoryModel>> fetchTradeHistory(
      String userId,
      ) async {
    final data = await _client
        .from('stock_trade_history')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(20);

    return (data as List)
        .map(
          (e) => StockTradeHistoryModel.fromMap(
        Map<String, dynamic>.from(e),
      ),
    )
        .toList();
  }

  Future<List<StockPendingOrderModel>> fetchPendingOrders(
      String userId,
      ) async {
    final data = await _client
        .from('stock_pending_orders')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (data as List)
        .map(
          (e) => StockPendingOrderModel.fromMap(
        Map<String, dynamic>.from(e),
      ),
    )
        .toList();
  }

  Future<void> processPendingOrders() async {
    final pendingOrders = await _client
        .from('stock_pending_orders')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    final orders =
    List<Map<String, dynamic>>.from(
      pendingOrders,
    );

    for (final order in orders) {
      final String orderId =
      order['id'].toString();

      final String userId =
      order['user_id'].toString();

      final String stockCode =
      order['stock_code'].toString();

      final String stockName =
      order['stock_name'].toString();

      final String orderType =
      order['order_type'].toString();

      final double orderPrice =
      ((order['order_price'] ?? 0) as num)
          .toDouble();

      final int quantity =
      ((order['quantity'] ?? 0) as num)
          .toInt();

      if (quantity <= 0 ||
          orderPrice <= 0) {
        continue;
      }

      final stockRows = await _client
          .from('stock_item')
          .select('current_price')
          .eq('code', stockCode)
          .limit(1);

      final stocks =
      List<Map<String, dynamic>>.from(
        stockRows,
      );

      if (stocks.isEmpty) {
        continue;
      }

      final double currentPrice =
      ((stocks.first['current_price'] ?? 0)
      as num)
          .toDouble();

      final bool canFill =
          currentPrice == orderPrice;

      if (!canFill) {
        continue;
      }

      if (orderType == 'buy') {
        await buyStock(
          userId: userId,
          stockCode: stockCode,
          stockName: stockName,
          price: orderPrice,
          quantity: quantity,
        );
      } else if (orderType == 'sell') {
        await sellStock(
          userId: userId,
          stockCode: stockCode,
          stockName: stockName,
          price: orderPrice,
          quantity: quantity,
        );
      }

      await _client
          .from('stock_pending_orders')
          .update({
        'status': 'filled',
        'filled_price': orderPrice,
        'filled_at':
        DateTime.now()
            .toIso8601String(),
      })
          .eq('id', orderId);
    }
  }

  Future<void> createPendingOrder({
    required String userId,
    required String stockCode,
    required String stockName,
    required String orderType,
    required double orderPrice,
    required int quantity,
  }) async {
    if (userId.trim().isEmpty) {
      throw Exception(
        '로그인 정보가 올바르지 않습니다.',
      );
    }

    if (stockCode.trim().isEmpty ||
        stockName.trim().isEmpty) {
      throw Exception(
        '종목 정보가 올바르지 않습니다.',
      );
    }

    if (orderType != 'buy' &&
        orderType != 'sell') {
      throw Exception(
        '주문 구분이 올바르지 않습니다.',
      );
    }

    if (orderPrice <= 0) {
      throw Exception(
        '주문가격이 올바르지 않습니다.',
      );
    }

    if (quantity <= 0) {
      throw Exception(
        '수량은 1주 이상이어야 합니다.',
      );
    }

    await _client
        .from('stock_pending_orders')
        .insert({
      'user_id': userId,
      'stock_code': stockCode,
      'stock_name': stockName,
      'order_type': orderType,
      'order_price': orderPrice,
      'quantity': quantity,
      'status': 'pending',
    });
  }

  Future<void> cancelPendingOrder({
    required String userId,
    required String orderId,
  }) async {
    if (userId.trim().isEmpty) {
      throw Exception(
        '로그인 정보가 올바르지 않습니다.',
      );
    }

    if (orderId.trim().isEmpty) {
      throw Exception(
        '주문 정보가 올바르지 않습니다.',
      );
    }

    await _client
        .from('stock_pending_orders')
        .update({
      'status': 'cancelled',
      'updated_at':
      DateTime.now()
          .toIso8601String(),
    })
        .eq('id', orderId)
        .eq('user_id', userId)
        .eq('status', 'pending');
  }

  // 주식계좌 현금 조회
  Future<int> _fetchStockAccountCash(
      String userId,
      ) async {
    final response = await _client
        .from('user_asset_accounts')
        .select('cash_balance')
        .eq('user_id', userId)
        .eq('account_type', 'stock')
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) {
      throw Exception(
        '주식 투자 계좌를 찾을 수 없습니다.',
      );
    }

    return ((response['cash_balance'] ?? 0)
    as num)
        .round();
  }

  // 주식화면 표시용 주식계좌 현금 조회
  Future<double> fetchStockAccountCashBalance(
      String userId,
      ) async {
    final int cash =
    await _fetchStockAccountCash(
      userId,
    );

    return cash.toDouble();
  }

  // 주식계좌 현금 변경
  Future<void> _updateStockAccountCash({
    required String userId,
    required int cashBalance,
  }) async {
    await _client
        .from('user_asset_accounts')
        .update({
      'cash_balance': cashBalance,
      'updated_at':
      DateTime.now()
          .toIso8601String(),
    })
        .eq('user_id', userId)
        .eq('account_type', 'stock')
        .eq('is_active', true);
  }

  Future<void> buyStock({
    required String userId,
    required String stockCode,
    required String stockName,
    required double price,
    required int quantity,
  }) async {
    if (userId.trim().isEmpty) {
      throw Exception(
        '로그인 정보가 올바르지 않습니다.',
      );
    }

    if (stockCode.trim().isEmpty ||
        stockName.trim().isEmpty) {
      throw Exception(
        '종목 정보가 올바르지 않습니다.',
      );
    }

    if (price <= 0) {
      throw Exception(
        '종목 가격이 올바르지 않습니다.',
      );
    }

    if (quantity <= 0) {
      throw Exception(
        '수량은 1주 이상이어야 합니다.',
      );
    }

    final double rawAmount =
        price * quantity;

    // 매수 수수료 없음
    final double fee =
        rawAmount * _stockBuyFeeRate;

    final int totalAmount =
    (rawAmount + fee).round();

    final int latestStockCash =
    await _fetchStockAccountCash(
      userId,
    );

    if (latestStockCash < totalAmount) {
      throw Exception(
        '주식계좌 현금이 부족합니다.',
      );
    }

    final existing = await _client
        .from('stock_holdings')
        .select()
        .eq('user_id', userId)
        .eq('stock_code', stockCode)
        .maybeSingle();

    if (existing == null) {
      await _client
          .from('stock_holdings')
          .insert({
        'user_id': userId,
        'stock_code': stockCode,
        'stock_name': stockName,
        'quantity': quantity,
        'average_price': price,
      });
    } else {
      final int currentQuantity =
          (existing['quantity'] as num?)
              ?.toInt() ??
              0;

      final double currentAveragePrice =
      ((existing['average_price']
      as num?) ??
          0)
          .toDouble();

      final int newQuantity =
          currentQuantity + quantity;

      final double newAveragePrice =
          ((currentQuantity *
              currentAveragePrice) +
              (quantity * price)) /
              newQuantity;

      await _client
          .from('stock_holdings')
          .update({
        'quantity': newQuantity,
        'average_price':
        newAveragePrice,
      })
          .eq(
        'id',
        existing['id'],
      );
    }

    final int stockCashAfterBuy =
        latestStockCash - totalAmount;

    await _updateStockAccountCash(
      userId: userId,
      cashBalance: stockCashAfterBuy,
    );

    // 주식 투자계좌 출금내역
    await _client
        .from('asset_account_transactions')
        .insert({
      'user_id': userId,

      // 계좌 구분
      'account_type': 'stock',

      'type': 'out',
      'reason': 'stock_buy',
      'amount': totalAmount,
      'balance_after':
      stockCashAfterBuy,
      'title': '주식 매수',
      'memo':
      '$stockName $quantity주',
      'created_at':
      DateTime.now()
          .toIso8601String(),
    });

    final stockItem = await _client
        .from('stock_item')
        .select('id')
        .eq('code', stockCode)
        .maybeSingle();

    if (stockItem == null) {
      throw Exception(
        '종목 정보를 찾을 수 없습니다.',
      );
    }

    await _client
        .from('stock_trade_history')
        .insert({
      'user_id': userId,
      'stock_item_id':
      stockItem['id'],
      'stock_code': stockCode,
      'stock_name': stockName,
      'trade_type': 'buy',
      'quantity': quantity,
      'price': price,

      // 매수 수수료가 없으므로
      // 실제 매수금액과 동일
      'total_amount': totalAmount,
    });

    await _client.rpc(
      'apply_stock_trade',
      params: {
        'p_stock_id':
        stockItem['id'],
        'p_trade_price': price,
        'p_quantity': quantity,
        'p_is_buy': true,
      },
    );
  }

  Future<void> sellStock({
    required String userId,
    required String stockCode,
    required String stockName,
    required double price,
    required int quantity,
  }) async {
    if (userId.trim().isEmpty) {
      throw Exception(
        '로그인 정보가 올바르지 않습니다.',
      );
    }

    if (stockCode.trim().isEmpty ||
        stockName.trim().isEmpty) {
      throw Exception(
        '종목 정보가 올바르지 않습니다.',
      );
    }

    if (price <= 0) {
      throw Exception(
        '종목 가격이 올바르지 않습니다.',
      );
    }

    if (quantity <= 0) {
      throw Exception(
        '수량은 1주 이상이어야 합니다.',
      );
    }

    final existing = await _client
        .from('stock_holdings')
        .select()
        .eq('user_id', userId)
        .eq('stock_code', stockCode)
        .maybeSingle();

    if (existing == null) {
      throw Exception(
        '보유 중인 종목이 아닙니다.',
      );
    }

    final int currentQuantity =
        (existing['quantity'] as num?)
            ?.toInt() ??
            0;

    if (currentQuantity <= 0) {
      throw Exception(
        '보유 수량이 없습니다.',
      );
    }

    if (currentQuantity < quantity) {
      throw Exception(
        '보유 수량이 부족합니다.',
      );
    }

    final double rawAmount =
        price * quantity;

    // 매도 수수료 0.15%
    final double fee =
        rawAmount * _stockSellFeeRate;

    // 실제 주식계좌에 들어오는 금액
    final int receiveAmount =
    (rawAmount - fee).round();

    if (receiveAmount <= 0) {
      throw Exception(
        '매도 금액이 올바르지 않습니다.',
      );
    }

    final int latestStockCash =
    await _fetchStockAccountCash(
      userId,
    );

    final int remainQuantity =
        currentQuantity - quantity;

    if (remainQuantity <= 0) {
      await _client
          .from('stock_holdings')
          .delete()
          .eq(
        'id',
        existing['id'],
      );
    } else {
      await _client
          .from('stock_holdings')
          .update({
        'quantity':
        remainQuantity,
      })
          .eq(
        'id',
        existing['id'],
      );
    }

    final int stockCashAfterSell =
        latestStockCash +
            receiveAmount;

    await _updateStockAccountCash(
      userId: userId,
      cashBalance:
      stockCashAfterSell,
    );

    // 주식 투자계좌 입금내역
    await _client
        .from('asset_account_transactions')
        .insert({
      'user_id': userId,

      // 계좌 구분
      'account_type': 'stock',

      'type': 'in',
      'reason': 'stock_sell',
      'amount': receiveAmount,
      'balance_after':
      stockCashAfterSell,
      'title': '주식 매도',
      'memo':
      '$stockName $quantity주',
      'created_at':
      DateTime.now()
          .toIso8601String(),
    });

    final stockItem = await _client
        .from('stock_item')
        .select('id')
        .eq('code', stockCode)
        .maybeSingle();

    if (stockItem == null) {
      throw Exception(
        '종목 정보를 찾을 수 없습니다.',
      );
    }

    await _client
        .from('stock_trade_history')
        .insert({
      'user_id': userId,
      'stock_item_id':
      stockItem['id'],
      'stock_code': stockCode,
      'stock_name': stockName,
      'trade_type': 'sell',
      'quantity': quantity,
      'price': price,

      // 수수료 공제 후 실제 체결금액
      'total_amount':
      receiveAmount,
    });

    await _client.rpc(
      'apply_stock_trade',
      params: {
        'p_stock_id':
        stockItem['id'],
        'p_trade_price': price,
        'p_quantity': quantity,
        'p_is_buy': false,
      },
    );
  }
}