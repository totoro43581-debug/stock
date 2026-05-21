import 'package:supabase_flutter/supabase_flutter.dart';

class AssetAccountRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> ensureUserAssetAccounts() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return;
    }

    final response = await _client
        .from('user_asset_accounts')
        .select('account_type')
        .eq('user_id', user.id)
        .eq('is_active', true);

    final existingTypes = List<Map<String, dynamic>>.from(response)
        .map((item) => (item['account_type'] ?? '').toString())
        .toSet();

    final List<Map<String, dynamic>> insertRows = [];

    if (!existingTypes.contains('bank')) {
      insertRows.add({
        'user_id': user.id,
        'account_type': 'bank',
        'account_name': '생활 현금 계좌',
        'institution_code': 'DEFAULT_BANK',
        'account_number': 'BANK-${user.id}',
        'cash_balance': 0,
        'is_primary': true,
        'is_active': true,
      });
    }

    if (!existingTypes.contains('stock')) {
      insertRows.add({
        'user_id': user.id,
        'account_type': 'stock',
        'account_name': '주식 투자 계좌',
        'institution_code': 'DEFAULT_STOCK',
        'account_number': 'STOCK-${user.id}',
        'cash_balance': 0,
        'is_primary': true,
        'is_active': true,
      });
    }

    if (!existingTypes.contains('coin')) {
      insertRows.add({
        'user_id': user.id,
        'account_type': 'coin',
        'account_name': '코인 투자 계좌',
        'institution_code': 'DEFAULT_COIN',
        'account_number': 'COIN-${user.id}',
        'cash_balance': 0,
        'is_primary': true,
        'is_active': true,
      });
    }

    if (insertRows.isEmpty) {
      return;
    }

    await _client.from('user_asset_accounts').insert(insertRows);
  }

  Future<List<Map<String, dynamic>>> fetchUserAssetAccounts() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return [];
    }

    final response = await _client
        .from('user_asset_accounts')
        .select()
        .eq('user_id', user.id)
        .eq('is_active', true)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }
}