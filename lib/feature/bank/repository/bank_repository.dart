import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/bank/model/bank_product_model.dart';
import 'package:stock/feature/bank/model/user_bank_account_model.dart';

class BankRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Map<String, dynamic> _withBankName(Map<String, dynamic> row) {
    final bank = row['bank'];

    return {
      ...row,
      'bank_name': bank is Map ? bank['bank_name']?.toString() ?? '' : '',
    };
  }

  // 수정22차: 활성 예금/적금 상품 전체 조회 + 중도해지 인정률 포함
  Future<List<BankProductModel>> fetchActiveBankProducts() async {
    final response = await _client
        .from('bank_products')
        .select(
      '''
          id,
          product_code,
          product_name,
          product_type,
          description,
          annual_rate,
          term_days,
          min_amount,
          max_amount,
          installment_count,
          installment_interval_days,
          early_cancel_rate,
          is_active,
          bank:banks!bank_products_bank_id_fkey(
            bank_name
          )
          ''',
    )
        .eq('is_active', true)
        .order('product_type', ascending: true)
        .order('annual_rate', ascending: false);

    final rows = List<Map<String, dynamic>>.from(response);

    return rows
        .map((row) => BankProductModel.fromMap(_withBankName(row)))
        .toList();
  }

  // 수정22차: 예금 상품만 조회 + 중도해지 인정률 포함
  Future<List<BankProductModel>> fetchDepositProducts() async {
    final response = await _client
        .from('bank_products')
        .select(
      '''
          id,
          product_code,
          product_name,
          product_type,
          description,
          annual_rate,
          term_days,
          min_amount,
          max_amount,
          installment_count,
          installment_interval_days,
          early_cancel_rate,
          is_active,
          bank:banks!bank_products_bank_id_fkey(
            bank_name
          )
          ''',
    )
        .eq('is_active', true)
        .eq('product_type', 'deposit')
        .order('annual_rate', ascending: false);

    final rows = List<Map<String, dynamic>>.from(response);

    return rows
        .map((row) => BankProductModel.fromMap(_withBankName(row)))
        .toList();
  }

  // 수정22차: 적금 상품만 조회 + 중도해지 인정률 포함
  Future<List<BankProductModel>> fetchSavingsProducts() async {
    final response = await _client
        .from('bank_products')
        .select(
      '''
          id,
          product_code,
          product_name,
          product_type,
          description,
          annual_rate,
          term_days,
          min_amount,
          max_amount,
          installment_count,
          installment_interval_days,
          early_cancel_rate,
          is_active,
          bank:banks!bank_products_bank_id_fkey(
            bank_name
          )
          ''',
    )
        .eq('is_active', true)
        .eq('product_type', 'savings')
        .order('annual_rate', ascending: false);

    final rows = List<Map<String, dynamic>>.from(response);

    return rows
        .map((row) => BankProductModel.fromMap(_withBankName(row)))
        .toList();
  }

  // 수정2차: 로그인 유저의 보유 예금/적금 계좌 조회
  Future<List<UserBankAccountModel>> fetchMyBankAccounts() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await _client
        .from('user_bank_accounts')
        .select(
      '''
          id,
          user_id,
          product_id,
          product_name_snapshot,
          product_type,
          annual_rate_snapshot,
          principal_amount,
          installment_amount,
          total_installments,
          paid_installments,
          expected_interest_amount,
          expected_maturity_amount,
          start_at,
          maturity_at,
          next_payment_due_at,
          status,
          created_at,
          updated_at
          ''',
    )
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final rows = List<Map<String, dynamic>>.from(response);

    return rows.map((row) => UserBankAccountModel.fromMap(row)).toList();
  }

  // 수정2차: 로그인 유저의 활성 예금/적금 계좌 조회
  Future<List<UserBankAccountModel>> fetchMyActiveBankAccounts() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await _client
        .from('user_bank_accounts')
        .select(
      '''
          id,
          user_id,
          product_id,
          product_name_snapshot,
          product_type,
          annual_rate_snapshot,
          principal_amount,
          installment_amount,
          total_installments,
          paid_installments,
          expected_interest_amount,
          expected_maturity_amount,
          start_at,
          maturity_at,
          next_payment_due_at,
          status,
          created_at,
          updated_at
          ''',
    )
        .eq('user_id', user.id)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    final rows = List<Map<String, dynamic>>.from(response);

    return rows.map((row) => UserBankAccountModel.fromMap(row)).toList();
  }

  // 수정2차: 예금 가입 RPC 호출
  Future<Map<String, dynamic>> openDeposit({
    required String productId,
    required double amount,
  }) async {
    final response = await _client.rpc(
      'open_bank_deposit',
      params: {
        'p_product_id': productId,
        'p_amount': amount,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  // 수정2차: 적금 가입 RPC 호출
  Future<Map<String, dynamic>> openSavings({
    required String productId,
    required double installmentAmount,
  }) async {
    final response = await _client.rpc(
      'open_bank_savings',
      params: {
        'p_product_id': productId,
        'p_installment_amount': installmentAmount,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  // 수정8차: 적금 회차 납입 RPC 호출
  Future<Map<String, dynamic>> paySavingsInstallment({
    required String accountId,
  }) async {
    final response = await _client.rpc(
      'pay_bank_savings_installment',
      params: {
        'p_account_id': accountId,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  // 수정9차: 예금/적금 만기 수령 RPC 호출
  Future<Map<String, dynamic>> claimBankProductAccount({
    required String accountId,
  }) async {
    final response = await _client.rpc(
      'claim_bank_product_account',
      params: {
        'p_account_id': accountId,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  // 수정10차: 예금/적금 중도해지 RPC 호출
  Future<Map<String, dynamic>> cancelBankProductAccount({
    required String accountId,
  }) async {
    final response = await _client.rpc(
      'cancel_bank_product_account',
      params: {
        'p_account_id': accountId,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }
}