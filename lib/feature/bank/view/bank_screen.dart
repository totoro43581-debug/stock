import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock/feature/bank/model/bank_product_model.dart';
import 'package:stock/feature/bank/model/user_bank_account_model.dart';
import 'package:stock/feature/bank/repository/bank_repository.dart';

class BankScreen extends StatefulWidget {
  const BankScreen({super.key});

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  final BankRepository _repository = BankRepository();

  bool _isLoading = true;
  bool _isProcessing = false;

  String _selectedProductType = 'deposit';

  List<BankProductModel> _depositProducts = [];
  List<BankProductModel> _savingsProducts = [];
  List<UserBankAccountModel> _myBankAccounts = [];

  final NumberFormat _moneyFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadBankData();
  }

  // 수정3차: 예금/적금 화면 전체 데이터 조회
  Future<void> _loadBankData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final depositProducts = await _repository.fetchDepositProducts();
      final savingsProducts = await _repository.fetchSavingsProducts();
      final myBankAccounts = await _repository.fetchMyActiveBankAccounts();

      if (!mounted) return;

      setState(() {
        _depositProducts = depositProducts;
        _savingsProducts = savingsProducts;
        _myBankAccounts = myBankAccounts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessageDialog(
        title: '안내',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // 수정3차: 예금/적금 가입 다이얼로그
  Future<void> _openJoinDialog(BankProductModel product) async {
    final TextEditingController amountController = TextEditingController();

    final String amountLabel =
    product.isDeposit ? '가입 금액' : '1회 납입 금액';

    final String buttonLabel =
    product.isDeposit ? '예금 가입' : '적금 가입';

    await showDialog<void>(
      context: context,
      barrierDismissible: !_isProcessing,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final rawText = amountController.text
                  .replaceAll(',', '')
                  .trim();

              final amount = double.tryParse(rawText);

              if (amount == null || amount <= 0) {
                Navigator.of(dialogContext).pop();

                _showMessageDialog(
                  title: '안내',
                  message: '$amountLabel을 올바르게 입력해 주세요.',
                );
                return;
              }

              if (amount < product.minAmount) {
                Navigator.of(dialogContext).pop();

                _showMessageDialog(
                  title: '안내',
                  message:
                  '최소 금액은 ${_formatMoney(product.minAmount)}원입니다.',
                );
                return;
              }

              if (product.maxAmount != null &&
                  amount > product.maxAmount!) {
                Navigator.of(dialogContext).pop();

                _showMessageDialog(
                  title: '안내',
                  message:
                  '최대 금액은 ${_formatMoney(product.maxAmount!)}원입니다.',
                );
                return;
              }

              setDialogState(() {
                _isProcessing = true;
              });

              try {
                if (product.isDeposit) {
                  await _repository.openDeposit(
                    productId: product.id,
                    amount: amount,
                  );
                } else {
                  await _repository.openSavings(
                    productId: product.id,
                    installmentAmount: amount,
                  );
                }

                if (!mounted) return;

                Navigator.of(dialogContext).pop();

                _showMessageDialog(
                  title: '완료',
                  message: product.isDeposit
                      ? '예금 가입이 완료되었습니다.'
                      : '적금 가입이 완료되었습니다.',
                );

                await _loadBankData();
              } catch (e) {
                if (!mounted) return;

                Navigator.of(dialogContext).pop();

                _showMessageDialog(
                  title: '안내',
                  message: e.toString().replaceFirst('Exception: ', ''),
                );
              } finally {
                _isProcessing = false;
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                product.productName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildJoinInfoRow(
                      label: '상품 구분',
                      value: product.isDeposit ? '예금' : '적금',
                    ),
                    _buildJoinInfoRow(
                      label: '금리',
                      value: '연 ${product.annualRate.toStringAsFixed(2)}%',
                    ),
                    _buildJoinInfoRow(
                      label: '기간',
                      value: '${product.termDays}일',
                    ),
                    _buildJoinInfoRow(
                      label: '최소 금액',
                      value: '${_formatMoney(product.minAmount)}원',
                    ),
                    _buildJoinInfoRow(
                      label: '최대 금액',
                      value: product.maxAmount == null
                          ? '제한 없음'
                          : '${_formatMoney(product.maxAmount!)}원',
                    ),
                    if (product.isSavings &&
                        product.installmentCount != null)
                      _buildJoinInfoRow(
                        label: '총 납입 회차',
                        value: '${product.installmentCount}회',
                      ),
                    const SizedBox(height: 18),
                    Text(
                      amountLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: '금액 입력',
                        suffixText: '원',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF111827),
                            width: 1.3,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        final onlyNumber =
                        value.replaceAll(RegExp(r'[^0-9]'), '');

                        if (onlyNumber.isEmpty) {
                          amountController.value =
                          const TextEditingValue(text: '');
                          return;
                        }

                        final parsed = int.tryParse(onlyNumber) ?? 0;
                        final formatted = _moneyFormat.format(parsed);

                        amountController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(
                            offset: formatted.length,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              actions: [
                SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: _isProcessing
                        ? null
                        : () {
                      Navigator.of(dialogContext).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF111827),
                      side: const BorderSide(
                        color: Color(0xFFD1D5DB),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _isProcessing ? '처리 중...' : buttonLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
  }

  // 수정3차: 공통 안내 팝업
  Future<void> _showMessageDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF374151),
            ),
          ),
          actions: [
            SizedBox(
              height: 42,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentProducts = _selectedProductType == 'deposit'
        ? _depositProducts
        : _savingsProducts;

    return Container(
      color: const Color(0xFFF5F7FB),
      child: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(),
            const SizedBox(height: 20),
            _buildMyAccountSection(),
            const SizedBox(height: 20),
            _buildProductSection(currentProducts),
          ],
        ),
      ),
    );
  }

  // 수정3차: 페이지 상단 제목
  Widget _buildPageHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '예금 · 적금',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '보유 현금을 예금 또는 적금 상품에 배치하여 안정적인 이자를 받을 수 있습니다.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  // 수정3차: 내 가입 상품 영역
  Widget _buildMyAccountSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 예금 · 적금',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          if (_myBankAccounts.isEmpty)
            Container(
              width: double.infinity,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                ),
              ),
              child: const Text(
                '가입한 예금 또는 적금이 없습니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < _myBankAccounts.length; i++) ...[
                  _buildMyAccountCard(_myBankAccounts[i]),
                  if (i != _myBankAccounts.length - 1)
                    const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // 수정3차: 내 예금/적금 계좌 카드
  Widget _buildMyAccountCard(UserBankAccountModel account) {
    final String accountTypeLabel =
    account.isDeposit ? '예금' : '적금';

    final String dueText = account.isDeposit
        ? '만기일 ${_formatDate(account.maturityAt)}'
        : '다음 납입일 ${_formatNullableDate(account.nextPaymentDueAt)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: account.isDeposit
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  accountTypeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: account.isDeposit
                        ? const Color(0xFF0369A1)
                        : const Color(0xFF15803D),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  account.productNameSnapshot,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '연 ${account.annualRateSnapshot.toStringAsFixed(2)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAccountStat(
                  label: account.isDeposit ? '가입 원금' : '현재 납입액',
                  value: '${_formatMoney(account.principalAmount)}원',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccountStat(
                  label: '예상 이자',
                  value:
                  '${_formatMoney(account.expectedInterestAmount)}원',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccountStat(
                  label: '만기 예상액',
                  value:
                  '${_formatMoney(account.expectedMaturityAmount)}원',
                ),
              ),
            ],
          ),
          if (account.isSavings) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  '납입 진행 ${account.paidInstallments}/${account.totalInstallments ?? 0}회',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: account.savingsProgressRate.clamp(0, 1),
                      backgroundColor: const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            dueText,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // 수정3차: 예금/적금 상품 영역
  Widget _buildProductSection(List<BankProductModel> currentProducts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '가입 가능한 상품',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              _buildProductTypeButton(
                label: '예금',
                type: 'deposit',
              ),
              const SizedBox(width: 8),
              _buildProductTypeButton(
                label: '적금',
                type: 'savings',
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (currentProducts.isEmpty)
            Container(
              width: double.infinity,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                ),
              ),
              child: const Text(
                '가입 가능한 상품이 없습니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < currentProducts.length; i++) ...[
                  _buildProductCard(currentProducts[i]),
                  if (i != currentProducts.length - 1)
                    const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // 수정3차: 예금/적금 상품 카드
  Widget _buildProductCard(BankProductModel product) {
    final String typeLabel = product.isDeposit ? '예금' : '적금';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: product.isDeposit
                  ? const Color(0xFFE0F2FE)
                  : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: product.isDeposit
                    ? const Color(0xFF0369A1)
                    : const Color(0xFF15803D),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.description ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _buildProductMetaText(
                      '연 ${product.annualRate.toStringAsFixed(2)}%',
                    ),
                    _buildProductMetaText(
                      '${product.termDays}일',
                    ),
                    _buildProductMetaText(
                      '최소 ${_formatMoney(product.minAmount)}원',
                    ),
                    _buildProductMetaText(
                      product.maxAmount == null
                          ? '최대 제한 없음'
                          : '최대 ${_formatMoney(product.maxAmount!)}원',
                    ),
                    if (product.isSavings &&
                        product.installmentCount != null)
                      _buildProductMetaText(
                        '${product.installmentCount}회 납입',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 112,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                _openJoinDialog(product);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(
                product.isDeposit ? '예금 가입' : '적금 가입',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTypeButton({
    required String label,
    required String type,
  }) {
    final bool isSelected = _selectedProductType == type;

    return SizedBox(
      height: 38,
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _selectedProductType = type;
          });
        },
        style: OutlinedButton.styleFrom(
          backgroundColor:
          isSelected ? const Color(0xFF111827) : Colors.white,
          foregroundColor:
          isSelected ? Colors.white : const Color(0xFF111827),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF111827)
                : const Color(0xFFD1D5DB),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildProductMetaText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF374151),
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildAccountStat({
    required String label,
    required String value,
  }) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinInfoRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF111827),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double value) {
    return _moneyFormat.format(value.floor());
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy.MM.dd').format(date.toLocal());
  }

  String _formatNullableDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('yyyy.MM.dd').format(date.toLocal());
  }
}