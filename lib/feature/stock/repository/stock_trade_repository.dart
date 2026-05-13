import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:stock/feature/stock/model/stock_holding_model.dart';
import 'package:stock/feature/stock/model/stock_pending_order_model.dart';
import 'package:stock/feature/stock/model/stock_trade_history_model.dart';
import 'package:stock/feature/wallet/model/wallet_model.dart';
import 'package:stock/feature/wallet/repository/wallet_repository.dart';

class StockTradeRepository {
  StockTradeRepository();

  final SupabaseClient _client = Supabase.instance.client;
  final WalletRepository _walletRepository = WalletRepository();

  Future<List<StockHoldingModel>> fetchHoldings(String userId) async {
    final data = await _client
        .from('stock_holdings')
        .select()
        .eq('user_id', userId)
        .gt('quantity', 0)
        .order('stock_name', ascending: true);

    return (data as List)
        .map((e) => StockHoldingModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<StockTradeHistoryModel>> fetchTradeHistory(String userId) async {
    final data = await _client
        .from('stock_trade_history')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(20);

    return (data as List)
        .map(
          (e) => StockTradeHistoryModel.fromMap(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<List<StockPendingOrderModel>> fetchPendingOrders(String userId) async {
    final data = await _client
        .from('stock_pending_orders')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (data as List)
        .map(
          (e) => StockPendingOrderModel.fromMap(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<void> processPendingOrders() async {
    final pendingOrders = await _client
        .from('stock_pending_orders')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    final orders = List<Map<String, dynamic>>.from(pendingOrders);

    for (final order in orders) {
      final orderId = order['id'].toString();
      final userId = order['user_id'].toString();
      final stockCode = order['stock_code'].toString();
      final stockName = order['stock_name'].toString();
      final orderType = order['order_type'].toString();
      final orderPrice = ((order['order_price'] ?? 0) as num).toDouble();
      final quantity = ((order['quantity'] ?? 0) as num).toInt();

      if (quantity <= 0 || orderPrice <= 0) continue;

      final stockRows = await _client
          .from('stock_item')
          .select('current_price')
          .eq('code', stockCode)
          .limit(1);

      final stocks = List<Map<String, dynamic>>.from(stockRows);

      if (stocks.isEmpty) continue;

      final currentPrice =
      ((stocks.first['current_price'] ?? 0) as num).toDouble();

      final bool canFill = currentPrice == orderPrice;

      if (!canFill) continue;

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
        'filled_at': DateTime.now().toIso8601String(),
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
      throw Exception('로그인 정보가 올바르지 않습니다.');
    }

    if (stockCode.trim().isEmpty || stockName.trim().isEmpty) {
      throw Exception('종목 정보가 올바르지 않습니다.');
    }

    if (orderType != 'buy' && orderType != 'sell') {
      throw Exception('주문 구분이 올바르지 않습니다.');
    }

    if (orderPrice <= 0) {
      throw Exception('주문가격이 올바르지 않습니다.');
    }

    if (quantity <= 0) {
      throw Exception('수량은 1주 이상이어야 합니다.');
    }

    await _client.from('stock_pending_orders').insert({
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
      throw Exception('로그인 정보가 올바르지 않습니다.');
    }

    if (orderId.trim().isEmpty) {
      throw Exception('주문 정보가 올바르지 않습니다.');
    }

    await _client
        .from('stock_pending_orders')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId)
        .eq('user_id', userId)
        .eq('status', 'pending');
  }

  // 수정1차: 매수 검증 로직 강화
  Future<void> buyStock({
    required String userId,
    required String stockCode,
    required String stockName,
    required double price,
    required int quantity,
  }) async {
    if (userId.trim().isEmpty) {
      throw Exception('로그인 정보가 올바르지 않습니다.');
    }

    if (stockCode.trim().isEmpty || stockName.trim().isEmpty) {
      throw Exception('종목 정보가 올바르지 않습니다.');
    }

    if (price <= 0) {
      throw Exception('종목 가격이 올바르지 않습니다.');
    }

    if (quantity <= 0) {
      throw Exception('수량은 1주 이상이어야 합니다.');
    }

    final double rawAmount = price * quantity;
    final int totalAmount = rawAmount.round();

    final WalletModel? latestWallet = await _walletRepository.fetchWallet(
      userId,
    );

    if (latestWallet == null) {
      throw Exception('지갑 정보를 찾을 수 없습니다.');
    }

    if (latestWallet.cashBalance < totalAmount) {
      throw Exception('보유 현금이 부족합니다.');
    }

    final existing = await _client
        .from('stock_holdings')
        .select()
        .eq('user_id', userId)
        .eq('stock_code', stockCode)
        .maybeSingle();

    if (existing == null) {
      await _client.from('stock_holdings').insert({
        'user_id': userId,
        'stock_code': stockCode,
        'stock_name': stockName,
        'quantity': quantity,
        'average_price': price,
      });
    } else {
      final int currentQuantity = (existing['quantity'] as num?)?.toInt() ?? 0;

      final double currentAveragePrice =
          ((existing['average_price'] as num?) ?? 0).toDouble();

      final int newQuantity = currentQuantity + quantity;

      final double newAveragePrice =
          ((currentQuantity * currentAveragePrice) + (quantity * price)) /
          newQuantity;

      await _client
          .from('stock_holdings')
          .update({'quantity': newQuantity, 'average_price': newAveragePrice})
          .eq('id', existing['id']);
    }

    await _walletRepository.updateCashBalance(
      userId: userId,
      cashBalance: latestWallet.cashBalance - totalAmount,
    );

    // 수정41차: stock_item_id 포함해서 거래 저장
    final stockItem = await _client
        .from('stock_item')
        .select('id')
        .eq('code', stockCode)
        .maybeSingle();

    if (stockItem == null) {
      throw Exception('종목 정보를 찾을 수 없습니다.');
    }

    await _client.from('stock_trade_history').insert({
      'user_id': userId,
      'stock_item_id': stockItem['id'], // 🔥 핵심
      'stock_code': stockCode,
      'stock_name': stockName,
      'trade_type': 'buy',
      'quantity': quantity,
      'price': price,
      'total_amount': totalAmount,
    });
  }

  // 수정1차: 매도 검증 로직 강화
  Future<void> sellStock({
    required String userId,
    required String stockCode,
    required String stockName,
    required double price,
    required int quantity,
  }) async {
    if (userId.trim().isEmpty) {
      throw Exception('로그인 정보가 올바르지 않습니다.');
    }

    if (stockCode.trim().isEmpty || stockName.trim().isEmpty) {
      throw Exception('종목 정보가 올바르지 않습니다.');
    }

    if (price <= 0) {
      throw Exception('종목 가격이 올바르지 않습니다.');
    }

    if (quantity <= 0) {
      throw Exception('수량은 1주 이상이어야 합니다.');
    }

    final existing = await _client
        .from('stock_holdings')
        .select()
        .eq('user_id', userId)
        .eq('stock_code', stockCode)
        .maybeSingle();

    if (existing == null) {
      throw Exception('보유 중인 종목이 아닙니다.');
    }

    final int currentQuantity = (existing['quantity'] as num?)?.toInt() ?? 0;

    if (currentQuantity <= 0) {
      throw Exception('보유 수량이 없습니다.');
    }

    if (currentQuantity < quantity) {
      throw Exception('보유 수량이 부족합니다.');
    }

    final double rawAmount = price * quantity;
    final double fee = rawAmount * 0.0015;
    final int totalAmount = (rawAmount - fee).round();

    final WalletModel? latestWallet = await _walletRepository.fetchWallet(
      userId,
    );

    if (latestWallet == null) {
      throw Exception('지갑 정보를 찾을 수 없습니다.');
    }

    final int remainQuantity = currentQuantity - quantity;

    if (remainQuantity <= 0) {
      await _client.from('stock_holdings').delete().eq('id', existing['id']);
    } else {
      await _client
          .from('stock_holdings')
          .update({'quantity': remainQuantity})
          .eq('id', existing['id']);
    }

    await _walletRepository.updateCashBalance(
      userId: userId,
      cashBalance: latestWallet.cashBalance + totalAmount,
    );

    final stockItem = await _client
        .from('stock_item')
        .select('id')
        .eq('code', stockCode)
        .maybeSingle();

    if (stockItem == null) {
      throw Exception('종목 정보를 찾을 수 없습니다.');
    }

    await _client.from('stock_trade_history').insert({
      'user_id': userId,
      'stock_item_id': stockItem['id'],
      'stock_code': stockCode,
      'stock_name': stockName,
      'trade_type': 'sell',
      'quantity': quantity,
      'price': price,
      'total_amount': price * quantity,
    });
  }
}
