import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/wallet/model/wallet_model.dart';
import 'package:stock/feature/wallet/repository/wallet_repository.dart';

class WalletService {
  WalletService({
    WalletRepository? repository,
  }) : _repository = repository ?? WalletRepository();

  final WalletRepository _repository;

  Future<WalletModel> ensureMyWallet() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인 사용자가 없습니다.');
    }

    return _repository.ensureWallet(user.id);
  }

  Future<WalletModel?> fetchMyWallet() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return null;
    }

    return _repository.fetchWallet(user.id);
  }
}