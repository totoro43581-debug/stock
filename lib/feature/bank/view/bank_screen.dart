import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock/feature/asset_account/repository/asset_account_repository.dart';
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
  final AssetAccountRepository _assetAccountRepository =
  AssetAccountRepository();

  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isProductSectionExpanded = false;

  String _selectedProductType = 'deposit';

  List<Map<String, dynamic>> _assetAccounts = [];
  List<Map<String, dynamic>> _bankTransactions = [];
  List<BankProductModel> _depositProducts = [];
  List<BankProductModel> _savingsProducts = [];
  List<UserBankAccountModel> _myBankAccounts = [];

  final NumberFormat _moneyFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadBankData();
  }

  Future<void> _loadBankData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _assetAccountRepository.ensureUserAssetAccounts();

      final assetAccounts =
      await _assetAccountRepository.fetchUserAssetAccounts();

      final bankTransactions =
      await _assetAccountRepository.fetchAssetAccountTransactions(
        reasons: [
          'asset_transfer',
          'asset_to_deposit',
          'deposit_to_asset',
          'asset_to_savings',
          'savings_to_asset',
          'asset_to_stock',
          'stock_to_asset',
          'asset_to_coin',
          'coin_to_asset',
        ],
        limit: 300,
      );

      final depositProducts = await _repository.fetchDepositProducts();
      final savingsProducts = await _repository.fetchSavingsProducts();
      final myBankAccounts = await _repository.fetchMyActiveBankAccounts();

      if (!mounted) return;

      setState(() {
        _assetAccounts = assetAccounts;
        _bankTransactions = bankTransactions;
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

  Future<void> _openJoinDialog(BankProductModel product) async {
    final TextEditingController amountController = TextEditingController();

    final String amountLabel = product.isDeposit ? '가입 금액' : '1회 납입 금액';
    final String buttonLabel = product.isDeposit ? '예금 가입' : '적금 가입';

    await showDialog<void>(
      context: context,
      barrierDismissible: !_isProcessing,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final rawText = amountController.text.replaceAll(',', '').trim();
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
                  message: '최소 금액은 ${_formatMoney(product.minAmount)}원입니다.',
                );
                return;
              }

              if (product.maxAmount != null && amount > product.maxAmount!) {
                Navigator.of(dialogContext).pop();

                _showMessageDialog(
                  title: '안내',
                  message: '최대 금액은 ${_formatMoney(product.maxAmount!)}원입니다.',
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

                if (!mounted || !dialogContext.mounted) return;

                Navigator.of(dialogContext).pop();

                _showMessageDialog(
                  title: '완료',
                  message: product.isDeposit
                      ? '예금 가입이 완료되었습니다.'
                      : '적금 가입이 완료되었습니다.',
                );

                await _loadBankData();
              } catch (e) {
                if (!mounted || !dialogContext.mounted) return;

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
                      label: '중도해지',
                      value:
                      '이자 ${(product.earlyCancelRate * 100).toStringAsFixed(0)}% 인정',
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
                    if (product.isSavings && product.installmentCount != null)
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
                      decoration: _amountInputDecoration(),
                      onChanged: (value) {
                        _formatAmountController(amountController, value);
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
                    style: _outlineButtonStyle(),
                    child: const Text(
                      '취소',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : submit,
                    style: _primaryButtonStyle(),
                    child: Text(
                      _isProcessing ? '처리 중...' : buttonLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
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

  Future<void> _openAssetTransferDialog(Map<String, dynamic> fromAccount) async {
    final TextEditingController amountController = TextEditingController();

    final String fromAccountType = fromAccount['account_type']?.toString() ?? '';
    final String fromAccountName =
        fromAccount['account_name']?.toString() ?? '-';

    final List<Map<String, dynamic>> toAccounts = _assetAccounts
        .where((account) => account['account_type'] != fromAccountType)
        .toList();

    String? selectedToAccountType =
    toAccounts.isEmpty ? null : toAccounts.first['account_type']?.toString();

    await showDialog<void>(
      context: context,
      barrierDismissible: !_isProcessing,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final rawText = amountController.text.replaceAll(',', '').trim();
              final amount = double.tryParse(rawText);

              if (selectedToAccountType == null ||
                  selectedToAccountType!.isEmpty) {
                Navigator.of(dialogContext).pop();

                _showMessageDialog(
                  title: '안내',
                  message: '입금 계좌를 선택해 주세요.',
                );
                return;
              }

              if (amount == null || amount <= 0) {
                Navigator.of(dialogContext).pop();

                _showMessageDialog(
                  title: '안내',
                  message: '이체 금액을 올바르게 입력해 주세요.',
                );
                return;
              }

              setDialogState(() {
                _isProcessing = true;
              });

              try {
                await _assetAccountRepository.transferAssetAccountBalance(
                  fromAccountType: fromAccountType,
                  toAccountType: selectedToAccountType!,
                  amount: amount,
                );

                if (!mounted || !dialogContext.mounted) return;

                Navigator.of(dialogContext).pop();

                _showMessageDialog(
                  title: '완료',
                  message: '계좌 이체가 완료되었습니다.',
                );

                await _loadBankData();
              } catch (e) {
                if (!mounted || !dialogContext.mounted) return;

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
              title: const Text(
                '계좌 이체',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildJoinInfoRow(
                      label: '출금 계좌',
                      value: fromAccountName,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '입금 계좌',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTransferAccountSelector(
                      toAccounts: toAccounts,
                      selectedToAccountType: selectedToAccountType,
                      onSelected: (accountType) {
                        setDialogState(() {
                          selectedToAccountType = accountType;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          '이체 금액',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildTransferQuickAmountButton(
                                label: '1만원',
                                amount: 10000,
                                controller: amountController,
                              ),
                              _buildTransferQuickAmountButton(
                                label: '5만원',
                                amount: 50000,
                                controller: amountController,
                              ),
                              _buildTransferQuickAmountButton(
                                label: '10만원',
                                amount: 100000,
                                controller: amountController,
                              ),
                              _buildTransferQuickAmountButton(
                                label: '100만원',
                                amount: 1000000,
                                controller: amountController,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: _amountInputDecoration(),
                      onChanged: (value) {
                        _formatAmountController(amountController, value);
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
                    style: _outlineButtonStyle(),
                    child: const Text(
                      '취소',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : submit,
                    style: _primaryButtonStyle(),
                    child: Text(
                      _isProcessing ? '처리 중...' : '이체',
                      style: const TextStyle(fontWeight: FontWeight.w800),
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

  Widget _buildTransferAccountSelector({
    required List<Map<String, dynamic>> toAccounts,
    required String? selectedToAccountType,
    required ValueChanged<String> onSelected,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < toAccounts.length; i++) ...[
            Builder(
              builder: (context) {
                final account = toAccounts[i];
                final accountType = account['account_type']?.toString() ?? '';
                final accountName = account['account_name']?.toString() ?? '-';
                final bool isSelected = selectedToAccountType == accountType;

                return InkWell(
                  onTap: _isProcessing
                      ? null
                      : () {
                    onSelected(accountType);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF111827)
                                  : const Color(0xFFD1D5DB),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF111827),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          accountName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (i != toAccounts.length - 1)
              const Divider(
                height: 1,
                color: Color(0xFFE5E7EB),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransferQuickAmountButton({
    required String label,
    required int amount,
    required TextEditingController controller,
  }) {
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: _isProcessing
            ? null
            : () {
          _setTransferQuickAmount(
            controller: controller,
            amount: amount,
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF111827),
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 수정27차: 이체 금액 빠른 버튼은 기존 입력값에 합산
  void _setTransferQuickAmount({
    required TextEditingController controller,
    required int amount,
  }) {
    final String currentText = controller.text.replaceAll(',', '').trim();
    final int currentAmount = int.tryParse(currentText) ?? 0;

    final int nextAmount = currentAmount + amount;
    final String formatted = _moneyFormat.format(nextAmount);

    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _paySavingsInstallment(UserBankAccountModel account) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _repository.paySavingsInstallment(accountId: account.id);

      if (!mounted) return;

      _showMessageDialog(
        title: '완료',
        message: '적금 납입이 완료되었습니다.',
      );

      await _loadBankData();
    } catch (e) {
      if (!mounted) return;

      _showMessageDialog(
        title: '안내',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _claimBankProductAccount(UserBankAccountModel account) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _repository.claimBankProductAccount(accountId: account.id);

      if (!mounted) return;

      _showMessageDialog(
        title: '완료',
        message: '만기 수령이 완료되었습니다.',
      );

      await _loadBankData();
    } catch (e) {
      if (!mounted) return;

      _showMessageDialog(
        title: '안내',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _cancelBankProductAccount(UserBankAccountModel account) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _repository.cancelBankProductAccount(accountId: account.id);

      if (!mounted) return;

      _showMessageDialog(
        title: '완료',
        message: '중도해지가 완료되었습니다.',
      );

      await _loadBankData();
    } catch (e) {
      if (!mounted) return;

      _showMessageDialog(
        title: '안내',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

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
                style: _primaryButtonStyle(),
                child: const Text(
                  '확인',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openTransactionHistoryDialog({
    required Map<String, dynamic> account,
  }) async {
    final String accountType = account['account_type']?.toString() ?? '';
    final String accountName = account['account_name']?.toString() ?? '-';

    String selectedPeriod = 'recent';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final List<Map<String, dynamic>> accountTransactions =
            _bankTransactions.where((transaction) {
              return _isTransactionForAccount(
                transaction: transaction,
                accountType: accountType,
                accountName: accountName,
              );
            }).toList();

            final List<Map<String, dynamic>> filteredTransactions =
            _filterTransactionsByPeriod(
              transactions: accountTransactions,
              period: selectedPeriod,
            );

            return AlertDialog(
              backgroundColor: Colors.white,
              titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$accountName 결제내역',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_transactionPeriodLabel(selectedPeriod)} ${filteredTransactions.length}건',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 620,
                height: 510,
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildTransactionPeriodButton(
                          label: '최근',
                          period: 'recent',
                          selectedPeriod: selectedPeriod,
                          onTap: () {
                            setDialogState(() {
                              selectedPeriod = 'recent';
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildTransactionPeriodButton(
                          label: '1개월',
                          period: '1m',
                          selectedPeriod: selectedPeriod,
                          onTap: () {
                            setDialogState(() {
                              selectedPeriod = '1m';
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildTransactionPeriodButton(
                          label: '3개월',
                          period: '3m',
                          selectedPeriod: selectedPeriod,
                          onTap: () {
                            setDialogState(() {
                              selectedPeriod = '3m';
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildTransactionPeriodButton(
                          label: '1년',
                          period: '1y',
                          selectedPeriod: selectedPeriod,
                          onTap: () {
                            setDialogState(() {
                              selectedPeriod = '1y';
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildTransactionPeriodButton(
                          label: '전체',
                          period: 'all',
                          selectedPeriod: selectedPeriod,
                          onTap: () {
                            setDialogState(() {
                              selectedPeriod = 'all';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: filteredTransactions.isEmpty
                          ? Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: const Text(
                          '표시할 결제내역이 없습니다.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      )
                          : ListView.separated(
                        physics: const ClampingScrollPhysics(),
                        itemCount: filteredTransactions.length,
                        separatorBuilder: (context, index) {
                          return const SizedBox(height: 8);
                        },
                        itemBuilder: (context, index) {
                          return _buildTransactionHistoryRow(
                            filteredTransactions[index],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    style: _primaryButtonStyle(),
                    child: const Text(
                      '확인',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionPeriodButton({
    required String label,
    required String period,
    required String selectedPeriod,
    required VoidCallback onTap,
  }) {
    final bool isSelected = period == selectedPeriod;

    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF111827) : Colors.white,
          foregroundColor: isSelected ? Colors.white : const Color(0xFF111827),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF111827)
                : const Color(0xFFD1D5DB),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionHistoryRow(Map<String, dynamic> transaction) {
    final String type = transaction['type']?.toString() ?? '';
    final String reason = transaction['reason']?.toString() ?? '';
    final String title = transaction['title']?.toString() ?? '';
    final String memo = transaction['memo']?.toString() ?? '';
    final double amount = _toDouble(transaction['amount']);
    final double balanceAfter = _toDouble(transaction['balance_after']);

    final bool isDeposit = type == 'deposit';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDeposit
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isDeposit ? '입금' : '출금',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isDeposit
                    ? const Color(0xFF15803D)
                    : const Color(0xFFDC2626),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? _transactionReasonLabel(reason) : title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  memo.isEmpty ? _transactionReasonLabel(reason) : memo,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isDeposit ? '+' : '-'}${_formatMoney(amount)}원',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDeposit
                      ? const Color(0xFF15803D)
                      : const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '잔액 ${_formatMoney(balanceAfter)}원',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 수정40차: 계좌별 결제내역 방향 필터 수정
  bool _isTransactionForAccount({
    required Map<String, dynamic> transaction,
    required String accountType,
    required String accountName,
  }) {
    final String type = transaction['type']?.toString() ?? '';
    final String reason = transaction['reason']?.toString() ?? '';
    final String title = transaction['title']?.toString() ?? '';
    final String memo = transaction['memo']?.toString() ?? '';
    final String combinedText = '$title $memo';

    final String normalizedMemo = memo.replaceAll('→', '->');

    final bool isTransfer = reason == 'asset_transfer';
    final bool isAccountTransferOut =
        isTransfer && normalizedMemo.startsWith(accountName);
    final bool isAccountTransferIn =
        isTransfer && normalizedMemo.endsWith(accountName);

    final bool isThisAccountTransfer =
        (type == 'withdraw' && isAccountTransferOut) ||
            (type == 'deposit' && isAccountTransferIn);

    if (accountType == 'bank') {
      return isThisAccountTransfer ||
          reason == 'asset_to_deposit' ||
          reason == 'deposit_to_asset' ||
          reason == 'asset_to_savings' ||
          reason == 'savings_to_asset';
    }

    if (accountType == 'stock') {
      return isThisAccountTransfer ||
          reason == 'asset_to_stock' ||
          reason == 'stock_to_asset';
    }

    if (accountType == 'coin') {
      return isThisAccountTransfer ||
          reason == 'asset_to_coin' ||
          reason == 'coin_to_asset';
    }

    return combinedText.contains(accountName);
  }

  List<Map<String, dynamic>> _filterTransactionsByPeriod({
    required List<Map<String, dynamic>> transactions,
    required String period,
  }) {
    final DateTime now = DateTime.now();

    if (period == 'recent') {
      return transactions.take(10).toList();
    }

    if (period == 'all') {
      return transactions;
    }

    DateTime startDate;

    switch (period) {
      case '1m':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case '3m':
        startDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case '1y':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        return transactions.take(10).toList();
    }

    return transactions.where((transaction) {
      final DateTime? createdAt = _toNullableDateTime(
        transaction['created_at'],
      );

      if (createdAt == null) return false;

      return createdAt.isAfter(startDate) ||
          createdAt.isAtSameMomentAs(startDate);
    }).toList();
  }

  String _transactionPeriodLabel(String period) {
    switch (period) {
      case 'recent':
        return '최근';
      case '1m':
        return '1개월';
      case '3m':
        return '3개월';
      case '1y':
        return '1년';
      case 'all':
        return '전체';
      default:
        return '최근';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentProducts =
    _selectedProductType == 'deposit' ? _depositProducts : _savingsProducts;

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
            _buildAssetAccountSection(),
            const SizedBox(height: 20),
            _buildMyAccountSection(),
            const SizedBox(height: 20),
            _buildProductSection(currentProducts),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '계좌',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '입출금, 주식, 코인 계좌와 예금·적금 상품 계좌를 관리합니다.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetAccountSection() {
    final List<Map<String, dynamic>> orderedAccounts = [
      ..._assetAccounts.where((account) => account['account_type'] == 'bank'),
      ..._assetAccounts.where((account) => account['account_type'] == 'stock'),
      ..._assetAccounts.where((account) => account['account_type'] == 'coin'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 계좌',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          if (orderedAccounts.isEmpty)
            _buildEmptyBox('생성된 계좌가 없습니다.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900) {
                  return Column(
                    children: [
                      for (int i = 0; i < orderedAccounts.length; i++) ...[
                        _buildAssetAccountCard(orderedAccounts[i]),
                        if (i != orderedAccounts.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    for (int i = 0; i < orderedAccounts.length; i++) ...[
                      Expanded(
                        child: _buildAssetAccountCard(orderedAccounts[i]),
                      ),
                      if (i != orderedAccounts.length - 1)
                        const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAssetAccountCard(Map<String, dynamic> account) {
    final String accountType = account['account_type']?.toString() ?? '';
    final String accountName = account['account_name']?.toString() ?? '-';
    final double cashBalance = _toDouble(account['cash_balance']);
    final String typeLabel = _assetAccountTypeLabel(accountType);

    return Container(
      height: 138,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            typeLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            accountName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                    _openAssetTransferDialog(account);
                  },
                  style: _smallOutlineButtonStyle(),
                  child: const Text(
                    '이체',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: () {
                    _openTransactionHistoryDialog(account: account);
                  },
                  style: _smallOutlineButtonStyle(),
                  child: const Text(
                    '결제내역',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_formatMoney(cashBalance)}원',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyAccountSection() {
    final int depositCount =
        _myBankAccounts.where((account) => account.isDeposit).length;
    final int savingsCount =
        _myBankAccounts.where((account) => account.isSavings).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '금융상품 계좌',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              Text(
                '예금 $depositCount건 · 적금 $savingsCount건',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_myBankAccounts.isEmpty)
            _buildEmptyBox('가입한 예금 또는 적금이 없습니다.')
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

  Widget _buildMyAccountCard(UserBankAccountModel account) {
    final String accountTypeLabel = account.isDeposit ? '예금' : '적금';

    final String dueText = account.isDeposit
        ? '만기일 ${_formatDate(account.maturityAt)}'
        : '다음 납입일 ${_formatNullableDate(account.nextPaymentDueAt)}';

    final bool isMatured = DateTime.now().isAfter(account.maturityAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  value: '${_formatMoney(account.expectedInterestAmount)}원',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccountStat(
                  label: '만기 예상액',
                  value: '${_formatMoney(account.expectedMaturityAmount)}원',
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
                      value: account.savingsProgressRate
                          .clamp(0.0, 1.0)
                          .toDouble(),
                      backgroundColor: const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    onPressed: _isProcessing ||
                        account.paidInstallments >=
                            (account.totalInstallments ?? 0)
                        ? null
                        : () {
                      _paySavingsInstallment(account);
                    },
                    style: _primarySmallButtonStyle(),
                    child: Text(
                      account.paidInstallments >=
                          (account.totalInstallments ?? 0)
                          ? '완납'
                          : '납입',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  dueText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 34,
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                    if (isMatured) {
                      _claimBankProductAccount(account);
                    } else {
                      _cancelBankProductAccount(account);
                    }
                  },
                  style: _smallOutlineButtonStyle(),
                  child: Text(
                    isMatured ? '만기 수령' : '중도해지',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductSection(List<BankProductModel> currentProducts) {
    final int depositCount = _depositProducts.length;
    final int savingsCount = _savingsProducts.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
              const SizedBox(width: 12),
              Text(
                '예금 $depositCount건 · 적금 $savingsCount건',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isProductSectionExpanded = !_isProductSectionExpanded;
                    });
                  },
                  icon: Icon(
                    _isProductSectionExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                  ),
                  label: Text(_isProductSectionExpanded ? '접기' : '펼치기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF111827),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isProductSectionExpanded) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                _buildProductTypeButton(label: '예금', type: 'deposit'),
                const SizedBox(width: 8),
                _buildProductTypeButton(label: '적금', type: 'savings'),
              ],
            ),
            const SizedBox(height: 18),
            if (currentProducts.isEmpty)
              _buildEmptyBox('가입 가능한 상품이 없습니다.')
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
        ],
      ),
    );
  }

  Widget _buildProductCard(BankProductModel product) {
    final String typeLabel = product.isDeposit ? '예금' : '적금';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                Row(
                  children: [
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: Text(
                        product.bankName.isEmpty
                            ? '은행 미지정'
                            : product.bankName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        product.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
                    _buildProductMetaText('${product.termDays}일'),
                    _buildProductMetaText(
                      '최소 ${_formatMoney(product.minAmount)}원',
                    ),
                    _buildProductMetaText(
                      product.maxAmount == null
                          ? '최대 제한 없음'
                          : '최대 ${_formatMoney(product.maxAmount!)}원',
                    ),
                    if (product.isSavings && product.installmentCount != null)
                      _buildProductMetaText(
                        '${product.installmentCount}회 납입',
                      ),
                    _buildProductMetaText(
                      '중도해지 이자 ${(product.earlyCancelRate * 100).toStringAsFixed(0)}%',
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
              onPressed: _isProcessing
                  ? null
                  : () {
                _openJoinDialog(product);
              },
              style: _primaryButtonStyle(),
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
          backgroundColor: isSelected ? const Color(0xFF111827) : Colors.white,
          foregroundColor: isSelected ? Colors.white : const Color(0xFF111827),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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

  Widget _buildEmptyBox(String message) {
    return Container(
      width: double.infinity,
      height: 92,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  InputDecoration _amountInputDecoration() {
    return InputDecoration(
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
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFF111827),
          width: 1.3,
        ),
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF111827),
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  ButtonStyle _primarySmallButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF111827),
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
      ),
    );
  }

  ButtonStyle _outlineButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF111827),
      side: const BorderSide(color: Color(0xFFD1D5DB)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  ButtonStyle _smallOutlineButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF111827),
      side: const BorderSide(color: Color(0xFFD1D5DB)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
      ),
    );
  }

  void _formatAmountController(
      TextEditingController controller,
      String value,
      ) {
    final onlyNumber = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (onlyNumber.isEmpty) {
      controller.value = const TextEditingValue(text: '');
      return;
    }

    final parsed = int.tryParse(onlyNumber) ?? 0;
    final formatted = _moneyFormat.format(parsed);

    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _transactionReasonLabel(String reason) {
    switch (reason) {
      case 'asset_transfer':
        return '계좌 이체';
      case 'asset_to_deposit':
        return '예금 가입';
      case 'deposit_to_asset':
        return '예금 수령';
      case 'asset_to_savings':
        return '적금 납입';
      case 'savings_to_asset':
        return '적금 수령';
      case 'asset_to_stock':
        return '주식 매수';
      case 'stock_to_asset':
        return '주식 매도';
      case 'asset_to_coin':
        return '코인 매수';
      case 'coin_to_asset':
        return '코인 매도';
      default:
        return '거래';
    }
  }

  String _assetAccountTypeLabel(String accountType) {
    switch (accountType) {
      case 'bank':
        return '입출금 계좌';
      case 'stock':
        return '주식 계좌';
      case 'coin':
        return '코인 계좌';
      default:
        return accountType;
    }
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

  DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}