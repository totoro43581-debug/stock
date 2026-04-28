import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/stock/model/stock_holding_model.dart';
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
        .map((e) => StockTradeHistoryModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> buyStock({
    required String userId,
    required String stockCode,
    required String stockName,
    required double price,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      throw Exception('수량은 1주 이상이어야 합니다.');
    }

    final double totalAmount = price * quantity;
    final WalletModel wallet = await _walletRepository.ensureWallet(userId);

    if (wallet.cashBalance < totalAmount.toInt()) {
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
      final currentQuantity = (existing['quantity'] as num?)?.toInt() ?? 0;
      final currentAveragePrice =
      ((existing['average_price'] as num?) ?? 0).toDouble();

      final int newQuantity = currentQuantity + quantity;
      final double newAveragePrice =
          ((currentQuantity * currentAveragePrice) + (quantity * price)) /
              newQuantity;

      await _client
          .from('stock_holdings')
          .update({
        'quantity': newQuantity,
        'average_price': newAveragePrice,
      })
          .eq('id', existing['id']);
    }

    await _walletRepository.updateCashBalance(
      userId: userId,
      cashBalance: wallet.cashBalance - totalAmount.toInt(),
    );

    await _client.from('stock_trade_history').insert({
      'user_id': userId,
      'stock_code': stockCode,
      'stock_name': stockName,
      'trade_type': 'buy',
      'quantity': quantity,
      'price': price,
      'total_amount': totalAmount,
    });
  }

  Future<void> sellStock({
    required String userId,
    required String stockCode,
    required String stockName,
    required double price,
    required int quantity,
  }) async {
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

    final currentQuantity = (existing['quantity'] as num?)?.toInt() ?? 0;
    if (currentQuantity < quantity) {
      throw Exception('보유 수량이 부족합니다.');
    }

    final double totalAmount = price * quantity;
    final WalletModel wallet = await _walletRepository.ensureWallet(userId);

    final int remainQuantity = currentQuantity - quantity;

    if (remainQuantity <= 0) {
      await _client
          .from('stock_holdings')
          .delete()
          .eq('id', existing['id']);
    } else {
      await _client
          .from('stock_holdings')
          .update({
        'quantity': remainQuantity,
      })
          .eq('id', existing['id']);
    }

    await _walletRepository.updateCashBalance(
      userId: userId,
      cashBalance: wallet.cashBalance + totalAmount.toInt(),
    );

    await _client.from('stock_trade_history').insert({
      'user_id': userId,
      'stock_code': stockCode,
      'stock_name': stockName,
      'trade_type': 'sell',
      'quantity': quantity,
      'price': price,
      'total_amount': totalAmount,
    });
  }
}