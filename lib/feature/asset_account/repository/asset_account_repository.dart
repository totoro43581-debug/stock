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
}