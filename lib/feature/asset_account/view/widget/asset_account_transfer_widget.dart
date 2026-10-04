import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../model/asset_account_model.dart';
import '../../repository/asset_account_repository.dart';

class AssetAccountTransferWidget extends StatefulWidget {
  final VoidCallback? onTransferCompleted;

  const AssetAccountTransferWidget({
    super.key,
    this.onTransferCompleted,
  });

  @override
  State<AssetAccountTransferWidget> createState() =>
      _AssetAccountTransferWidgetState();
}

class _AssetAccountTransferWidgetState
    extends State<AssetAccountTransferWidget> {
  final AssetAccountRepository _repository =
  AssetAccountRepository();

  final TextEditingController _amountController =
  TextEditingController();

  final NumberFormat _moneyFormat =
  NumberFormat('#,###');

  bool _isLoading = true;
  bool _isProcessing = false;

  List<AssetAccountModel> _accounts = [];

  String? _fromAccountType;
  String? _toAccountType;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await _repository.ensureUserAssetAccounts();

      final rows =
      await _repository.fetchUserAssetAccounts();

      final accounts = rows
          .map(AssetAccountModel.fromMap)
          .where((account) => account.isActive)
          .toList();

      if (!mounted) return;

      String? nextFrom = _fromAccountType;
      String? nextTo = _toAccountType;

      if (nextFrom == null ||
          !accounts.any(
                (account) =>
            account.accountType == nextFrom,
          )) {
        if (accounts.any(
              (account) =>
          account.accountType == 'bank',
        )) {
          nextFrom = 'bank';
        } else if (accounts.isNotEmpty) {
          nextFrom = accounts.first.accountType;
        }
      }

      if (nextTo == null ||
          nextTo == nextFrom ||
          !accounts.any(
                (account) =>
            account.accountType == nextTo,
          )) {
        final candidates = accounts
            .where(
              (account) =>
          account.accountType != nextFrom,
        )
            .toList();

        nextTo = candidates.isEmpty
            ? null
            : candidates.first.accountType;
      }

      setState(() {
        _accounts = accounts;
        _fromAccountType = nextFrom;
        _toAccountType = nextTo;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    }
  }

  AssetAccountModel? _findAccount(
      String? accountType,
      ) {
    if (accountType == null) {
      return null;
    }

    for (final account in _accounts) {
      if (account.accountType == accountType) {
        return account;
      }
    }

    return null;
  }

  double get _inputAmount {
    final String value = _amountController.text
        .replaceAll(',', '')
        .trim();

    return double.tryParse(value) ?? 0;
  }

  Future<void> _transfer() async {
    if (_isProcessing) return;

    final String? fromType =
        _fromAccountType;

    final String? toType =
        _toAccountType;

    if (fromType == null ||
        toType == null) {
      _showMessage(
        '이체 계좌를 선택해주세요.',
      );
      return;
    }

    if (fromType == toType) {
      _showMessage(
        '같은 계좌로는 이체할 수 없습니다.',
      );
      return;
    }

    final double amount =
        _inputAmount;

    if (amount <= 0) {
      _showMessage(
        '이체 금액을 입력해주세요.',
      );
      return;
    }

    final AssetAccountModel? fromAccount =
    _findAccount(fromType);

    if (fromAccount == null) {
      _showMessage(
        '출금 계좌를 찾을 수 없습니다.',
      );
      return;
    }

    if (fromAccount.cashBalance < amount) {
      _showMessage(
        '출금 계좌 잔액이 부족합니다.',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await _repository
          .transferAssetAccountBalance(
        fromAccountType: fromType,
        toAccountType: toType,
        amount: amount,
      );

      _amountController.clear();

      await _loadAccounts();

      if (!mounted) return;

      widget.onTransferCompleted?.call();

      _showMessage(
        '계좌이체가 완료되었습니다.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _swapAccounts() {
    if (_fromAccountType == null ||
        _toAccountType == null) {
      return;
    }

    setState(() {
      final String oldFrom =
      _fromAccountType!;

      _fromAccountType =
          _toAccountType;

      _toAccountType =
          oldFrom;
    });
  }

  void _setQuickAmount(
      double amount,
      ) {
    _amountController.text =
        amount.round().toString();
  }

  void _setAllAmount() {
    final account =
    _findAccount(_fromAccountType);

    if (account == null) return;

    _amountController.text =
        account.cashBalance
            .floor()
            .toString();
  }

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompact =
        MediaQuery.of(context).size.width < 760;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isCompact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          const Color(0xFFE5E7EB),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
        height: 160,
        child: Center(
          child:
          CircularProgressIndicator(),
        ),
      )
          : Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            '계좌 이체',
            style: TextStyle(
              fontSize: 17,
              fontWeight:
              FontWeight.w900,
              color:
              Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            '생활 현금 · 주식 · 코인 · 부동산 계좌 간 자금을 이동합니다.',
            style: TextStyle(
              fontSize: 12,
              fontWeight:
              FontWeight.w700,
              color:
              Color(0xFF6B7280),
            ),
          ),

          const SizedBox(height: 18),

          if (isCompact)
            _buildCompactAccounts()
          else
            _buildWideAccounts(),

          const SizedBox(height: 16),

          _buildAmountField(),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _quickButton(
                '1만원',
                    () => _setQuickAmount(
                  10000,
                ),
              ),
              _quickButton(
                '5만원',
                    () => _setQuickAmount(
                  50000,
                ),
              ),
              _quickButton(
                '10만원',
                    () => _setQuickAmount(
                  100000,
                ),
              ),
              _quickButton(
                '100만원',
                    () => _setQuickAmount(
                  1000000,
                ),
              ),
              _quickButton(
                '전액',
                _setAllAmount,
              ),
            ],
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed:
              _isProcessing
                  ? null
                  : _transfer,
              child: _isProcessing
                  ? const SizedBox(
                width: 20,
                height: 20,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                '이체하기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                  FontWeight
                      .w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideAccounts() {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _buildAccountSelector(
            title: '출금 계좌',
            value: _fromAccountType,
            excludeType:
            _toAccountType,
            onChanged: (value) {
              setState(() {
                _fromAccountType =
                    value;
              });
            },
          ),
        ),

        const SizedBox(width: 12),

        IconButton(
          onPressed: _swapAccounts,
          tooltip: '계좌 바꾸기',
          icon: const Icon(
            Icons.swap_horiz_rounded,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildAccountSelector(
            title: '입금 계좌',
            value: _toAccountType,
            excludeType:
            _fromAccountType,
            onChanged: (value) {
              setState(() {
                _toAccountType =
                    value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompactAccounts() {
    return Column(
      children: [
        _buildAccountSelector(
          title: '출금 계좌',
          value: _fromAccountType,
          excludeType:
          _toAccountType,
          onChanged: (value) {
            setState(() {
              _fromAccountType =
                  value;
            });
          },
        ),

        const SizedBox(height: 8),

        IconButton(
          onPressed: _swapAccounts,
          tooltip: '계좌 바꾸기',
          icon: const Icon(
            Icons.swap_vert_rounded,
          ),
        ),

        const SizedBox(height: 8),

        _buildAccountSelector(
          title: '입금 계좌',
          value: _toAccountType,
          excludeType:
          _fromAccountType,
          onChanged: (value) {
            setState(() {
              _toAccountType =
                  value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAccountSelector({
    required String title,
    required String? value,
    required String? excludeType,
    required ValueChanged<String?>
    onChanged,
  }) {
    final AssetAccountModel? account =
    _findAccount(value);

    final availableAccounts =
    _accounts
        .where(
          (item) =>
      item.accountType !=
          excludeType,
    )
        .toList();

    return Container(
      padding:
      const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
        const Color(0xFFF9FAFB),
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color:
          const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF6B7280),
            ),
          ),

          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration:
            const InputDecoration(
              border:
              OutlineInputBorder(),
              isDense: true,
            ),
            items: availableAccounts
                .map(
                  (item) =>
                  DropdownMenuItem(
                    value:
                    item.accountType,
                    child: Text(
                      _accountLabel(
                        item,
                      ),
                    ),
                  ),
            )
                .toList(),
            onChanged: onChanged,
          ),

          const SizedBox(height: 8),

          Text(
            account == null
                ? '잔액 -'
                : '잔액 ${_moneyFormat.format(account.cashBalance.floor())}원',
            style: const TextStyle(
              fontSize: 13,
              fontWeight:
              FontWeight.w900,
              color:
              Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return TextField(
      controller:
      _amountController,
      keyboardType:
      TextInputType.number,
      decoration:
      const InputDecoration(
        labelText: '이체 금액',
        suffixText: '원',
        border:
        OutlineInputBorder(),
      ),
    );
  }

  Widget _quickButton(
      String label,
      VoidCallback onPressed,
      ) {
    return OutlinedButton(
      onPressed:
      _isProcessing
          ? null
          : onPressed,
      child: Text(label),
    );
  }

  String _accountLabel(
      AssetAccountModel account,
      ) {
    switch (account.accountType) {
      case 'bank':
        return '생활 현금';

      case 'stock':
        return '주식 투자';

      case 'coin':
        return '코인 투자';

      case 'real_estate':
        return '부동산 투자';

      default:
        if (account.accountName.trim().isNotEmpty) {
          return account.accountName;
        }

        return account.accountType;
    }
  }
}