import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/stock/model/stock_price_model.dart';

class StockPriceRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<StockPriceModel>> fetchPricesByStockId(String stockId) async {
    final response = await _client
        .from('stock_prices')
        .select('id, stock_id, price, created_at')
        .eq('stock_id', stockId)
        .order('created_at', ascending: true);

    debugPrint('수정17차 chart rows for stockId=$stockId: $response');

    return List<Map<String, dynamic>>.from(response)
        .map((e) => StockPriceModel.fromMap(e))
        .toList();
  }

  // 수정19차: Supabase RPC로 전체 종목 가격 변동 실행
  Future<void> simulateStockPrices() async {
    await _client.rpc('simulate_stock_prices');
  }
}