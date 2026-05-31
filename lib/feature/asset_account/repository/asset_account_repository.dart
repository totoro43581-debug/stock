import 'package:supabase_flutter/supabase_flutter.dart';

class AssetAccountRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> ensureUserAssetAccounts() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return;
    }

    await _client.rpc('ensure_user_asset_accounts');
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

  // 수정13차: 자산 계좌 간 이체 RPC 호출
  Future<Map<String, dynamic>> transferAssetAccountBalance({
    required String fromAccountType,
    required String toAccountType,
    required double amount,
  }) async {
    final response = await _client.rpc(
      'transfer_asset_account_balance',
      params: {
        'p_from_account_type': fromAccountType,
        'p_to_account_type': toAccountType,
        'p_amount': amount,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  // 수정14차: 자산계좌 거래내역 저장
  Future<void> addAssetAccountTransaction({
    required String type,
    required String reason,
    required double amount,
    required double balanceAfter,
    required String title,
    String? memo,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return;
    }

    await _client.from('asset_account_transactions').insert({
      'user_id': user.id,
      'type': type,
      'reason': reason,
      'amount': amount,
      'balance_after': balanceAfter,
      'title': title,
      'memo': memo,
    });
  }

  // 수정15차: 전체/항목별 자산 거래내역 조회
  Future<List<Map<String, dynamic>>> fetchAssetAccountTransactions({
    List<String>? reasons,
    int limit = 30,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return [];
    }

    var query = _client
        .from('asset_account_transactions')
        .select()
        .eq('user_id', user.id);

    if (reasons != null && reasons.isNotEmpty) {
      query = query.inFilter('reason', reasons);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }
}