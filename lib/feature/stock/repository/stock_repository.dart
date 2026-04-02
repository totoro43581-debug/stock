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

  // 수정1차: 사용자 지갑 조회
  Future<double> fetchUserWallet() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인 필요');
    }

    final response = await _client
        .from('user_wallet')
        .select('cash_balance')
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) {
      return 0;
    }

    return (response['cash_balance'] as num).toDouble();
  }
}

