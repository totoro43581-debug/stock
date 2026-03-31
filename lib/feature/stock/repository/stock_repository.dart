import 'package:supabase_flutter/supabase_flutter.dart';

class StockRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchActiveStocks() async {
    final response = await _client
        .from('stock_item')
        .select('code, name, market, current_price, change_rate')
        .eq('is_active', true)
        .order('market', ascending: true)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }
}