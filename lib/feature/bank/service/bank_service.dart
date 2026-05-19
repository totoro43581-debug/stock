import 'package:stock/feature/bank/model/bank_product_model.dart';
import 'package:stock/feature/bank/model/user_bank_account_model.dart';
import 'package:stock/feature/bank/repository/bank_repository.dart';

class BankService {
  final BankRepository _repository = BankRepository();

  // 수정2차: 활성 은행 상품 전체 조회
  Future<List<BankProductModel>> loadActiveBankProducts() {
    return _repository.fetchActiveBankProducts();
  }

  // 수정2차: 예금 상품 조회
  Future<List<BankProductModel>> loadDepositProducts() {
    return _repository.fetchDepositProducts();
  }

  // 수정2차: 적금 상품 조회
  Future<List<BankProductModel>> loadSavingsProducts() {
    return _repository.fetchSavingsProducts();
  }

  // 수정2차: 내 전체 예금/적금 계좌 조회
  Future<List<UserBankAccountModel>> loadMyBankAccounts() {
    return _repository.fetchMyBankAccounts();
  }

  // 수정2차: 내 활성 예금/적금 계좌 조회
  Future<List<UserBankAccountModel>> loadMyActiveBankAccounts() {
    return _repository.fetchMyActiveBankAccounts();
  }

  // 수정2차: 예금 가입
  Future<String> joinDeposit({
    required BankProductModel product,
    required double amount,
  }) async {
    if (!product.isDeposit) {
      throw Exception('예금 상품이 아닙니다.');
    }

    if (amount < product.minAmount) {
      throw Exception('최소 가입 금액보다 작습니다.');
    }

    if (product.maxAmount != null && amount > product.maxAmount!) {
      throw Exception('최대 가입 금액을 초과했습니다.');
    }

    final result = await _repository.openDeposit(
      productId: product.id,
      amount: amount,
    );

    return result['message']?.toString() ?? '예금 가입이 완료되었습니다.';
  }

  // 수정2차: 적금 가입
  Future<String> joinSavings({
    required BankProductModel product,
    required double installmentAmount,
  }) async {
    if (!product.isSavings) {
      throw Exception('적금 상품이 아닙니다.');
    }

    if (installmentAmount < product.minAmount) {
      throw Exception('최소 회차 납입액보다 작습니다.');
    }

    if (product.maxAmount != null &&
        installmentAmount > product.maxAmount!) {
      throw Exception('최대 회차 납입액을 초과했습니다.');
    }

    final result = await _repository.openSavings(
      productId: product.id,
      installmentAmount: installmentAmount,
    );

    return result['message']?.toString() ?? '적금 가입이 완료되었습니다.';
  }
}