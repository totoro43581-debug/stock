import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/stock/model/stock_candle_model.dart';

class StockPriceRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // 수정71차: interval 데이터 없으면 1분봉으로 자동 fallback
  Future<List<StockCandleModel>> fetchCandlesByStockId(
      String stockId, {
        String intervalType = '1m',
      }) async {
    final items = await _fetchCandles(
      stockId: stockId,
      intervalType: intervalType,
    );

    if (items.isNotEmpty || intervalType == '1m') {
      return items;
    }

    return _fetchCandles(
      stockId: stockId,
      intervalType: '1m',
    );
  }

  Future<List<StockCandleModel>> _fetchCandles({
    required String stockId,
    required String intervalType,
  }) async {
    final response = await _client
        .from('stock_candles')
        .select('*')
        .eq('stock_id', int.parse(stockId))
        .eq('interval_type', intervalType)
        .order('created_at', ascending: false)
        .limit(500);

    final items = List<Map<String, dynamic>>.from(response)
        .map((e) => StockCandleModel.fromMap(e))
        .toList();

    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return items;
  }

  // 수정17차: 가상 거래량 기반 시장 갱신
  Future<void> simulateStockPrices() async {
    await _client.rpc('simulate_stock_prices_by_virtual_volume');
    await _client.rpc('refresh_stock_candle_intervals');
  }
}