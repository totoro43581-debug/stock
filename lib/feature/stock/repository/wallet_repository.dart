import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/wallet/model/wallet_model.dart';

class WalletRepository {
  WalletRepository();

  final SupabaseClient _client = Supabase.instance.client;

  // 수정1차: 최초 지급 금액
  static const int initialCashBalance = 10000000;

  // 수정1차: 지갑 1건 조회
  Future<WalletModel?> fetchWallet(String userId) async {
    final response = await _client
        .from('wallets')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return WalletModel.fromMap(response);
  }

  // 수정1차: 지갑 없으면 생성
  Future<void> createWalletIfNotExists(String userId) async {
    final existingWallet = await fetchWallet(userId);

    if (existingWallet != null) {
      return;
    }

    await _client.from('wallets').insert({
      'user_id': userId,
      'cash_balance': initialCashBalance,
    });
  }

  // 수정1차: 로그인 직후 안전 보장용
  Future<WalletModel> ensureWallet(String userId) async {
    await createWalletIfNotExists(userId);

    final wallet = await fetchWallet(userId);

    if (wallet == null) {
      throw Exception('지갑 생성 후 조회에 실패했습니다.');
    }

    return wallet;
  }

  // 수정1차: 보유 현금 갱신
  Future<void> updateCashBalance({
    required String userId,
    required int cashBalance,
  }) async {
    await _client
        .from('wallets')
        .update({'cash_balance': cashBalance})
        .eq('user_id', userId);
  }
}