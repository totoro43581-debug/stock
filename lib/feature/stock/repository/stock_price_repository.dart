import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/stock/model/stock_candle_model.dart';

class StockPriceRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // 수정24차: 캔들 조회
  Future<List<StockCandleModel>> fetchCandlesByStockId(String stockId) async {
    final response = await _client
        .from('stock_candles')
        .select('*')
        .eq('stock_id', int.parse(stockId))
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => StockCandleModel.fromMap(e))
        .toList();
  }

  // 기존 유지
  Future<void> simulateStockPrices() async {
    await _client.rpc('simulate_stock_prices');
  }
}