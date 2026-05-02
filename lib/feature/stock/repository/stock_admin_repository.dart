import 'package:supabase_flutter/supabase_flutter.dart';

class StockAdminRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> createStockItem({
    required String code,
    required String name,
    required String market,
    required int currentPrice,
    required double changeRate,
    required bool isActive,
  }) async {
    await _client.from('stock_item').insert({
      'code': code,
      'name': name,
      'market': market,
      'current_price': currentPrice,
      'change_rate': changeRate,
      'is_active': isActive,
    });
  }
}