import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/stock/model/stock_price_model.dart';

class StockPriceRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<StockPriceModel>> fetchPricesByStockId(String stockId) async {
    final response = await _client
        .from('stock_prices')
        .select('id, stock_id, price, recorded_at')
        .eq('stock_id', stockId)
        .order('recorded_at', ascending: true);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => StockPriceModel.fromMap(e))
        .toList();
  }
}