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
          .where(
            (account) => account.isActive,
      )
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
          nextFrom =
              accounts.first.accountType;
        }
      }

      if (nextTo == null ||
          !accounts.any(
                (account) =>
            account.accountType == nextTo,
          )) {
        if (accounts.any(
              (account) =>
          account.accountType == 'stock',
        )) {
          nextTo = 'stock';
        } else if (accounts.length >= 2) {
          nextTo =
              accounts[1].accountType;
        } else if (accounts.isNotEmpty) {
          nextTo =
              accounts.first.accountType;
        }
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

      _showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
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
      if (account.accountType ==
          accountType) {
        return account;
      }
    }

    return null;
  }

  double get _inputAmount {
    final value = _amountController.text
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

    final fromAccount =
    _findAccount(fromType);

    if (fromAccount == null) {
      _showMessage(
        '출금 계좌를 찾을 수 없습니다.',
      );
      return;
    }

    if (fromAccount.cashBalance <
        amount) {
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
      final oldFrom =
          _fromAccountType;

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
    _findAccount(
      _fromAccountType,
    );

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

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompact =
        MediaQuery.of(context).size.width <
            760;

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
        height: 140,
        child: Center(
          child:
          CircularProgressIndicator(),
        ),
      )
          : Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _buildHeader(),

          const SizedBox(
            height: 16,
          ),

          if (isCompact)
            _buildCompactAccounts()
          else
            _buildWideAccounts(),

          const SizedBox(
            height: 14,
          ),

          if (isCompact)
            _buildCompactAmountArea()
          else
            _buildWideAmountArea(),

          const SizedBox(
            height: 10,
          ),

          _buildQuickButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          '계좌 이체',
          style: TextStyle(
            fontSize: 17,
            fontWeight:
            FontWeight.w900,
            color:
            Color(0xFF111827),
          ),
        ),
        SizedBox(height: 4),
        Text(
          '생활 현금과 투자계좌 사이에서 자금을 이동합니다.',
          style: TextStyle(
            fontSize: 12,
            fontWeight:
            FontWeight.w700,
            color:
            Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildWideAccounts() {
    return Row(
      children: [
        Expanded(
          child: _buildAccountSelector(
            title: '출금 계좌',
            value:
            _fromAccountType,
            onChanged: (value) {
              setState(() {
                _fromAccountType =
                    value;
              });
            },
          ),
        ),

        const SizedBox(width: 12),

        SizedBox(
          width: 42,
          height: 42,
          child: IconButton(
            padding:
            EdgeInsets.zero,
            onPressed:
            _swapAccounts,
            tooltip: '계좌 바꾸기',
            icon: const Icon(
              Icons
                  .swap_horiz_rounded,
              size: 22,
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildAccountSelector(
            title: '입금 계좌',
            value:
            _toAccountType,
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
          value:
          _fromAccountType,
          onChanged: (value) {
            setState(() {
              _fromAccountType =
                  value;
            });
          },
        ),

        const SizedBox(height: 8),

        SizedBox(
          height: 36,
          child: IconButton(
            padding:
            EdgeInsets.zero,
            onPressed:
            _swapAccounts,
            tooltip: '계좌 바꾸기',
            icon: const Icon(
              Icons.swap_vert_rounded,
            ),
          ),
        ),

        const SizedBox(height: 8),

        _buildAccountSelector(
          title: '입금 계좌',
          value:
          _toAccountType,
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
    required ValueChanged<String?>
    onChanged,
  }) {
    final account =
    _findAccount(value);

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
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
          Row(
            children: [
              Text(
                title,
                style:
                const TextStyle(
                  fontSize: 11,
                  fontWeight:
                  FontWeight.w800,
                  color:
                  Color(0xFF6B7280),
                ),
              ),

              const Spacer(),

              Text(
                account == null
                    ? '잔액 -'
                    : '${_moneyFormat.format(account.cashBalance.floor())}원',
                style:
                const TextStyle(
                  fontSize: 12,
                  fontWeight:
                  FontWeight.w900,
                  color:
                  Color(0xFF111827),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          DropdownButtonHideUnderline(
            child:
            DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,

              dropdownColor: Colors.white,
              focusColor: Colors.transparent,

              borderRadius:
              BorderRadius.circular(
                12,
              ),
              icon: const Icon(
                Icons
                    .keyboard_arrow_down_rounded,
                size: 20,
              ),
              style:
              const TextStyle(
                fontSize: 14,
                fontWeight:
                FontWeight.w800,
                color:
                Color(0xFF111827),
              ),
              items: _accounts
                  .map(
                    (item) =>
                    DropdownMenuItem<
                        String>(
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
          ),
        ],
      ),
    );
  }

  Widget _buildWideAmountArea() {
    return Row(
      children: [
        Expanded(
          child:
          _buildAmountField(),
        ),

        const SizedBox(width: 10),

        SizedBox(
          width: 160,
          height: 44,
          child:
          _buildTransferButton(),
        ),
      ],
    );
  }

  Widget _buildCompactAmountArea() {
    return Column(
      children: [
        _buildAmountField(),

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          height: 44,
          child:
          _buildTransferButton(),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller:
        _amountController,
        keyboardType:
        TextInputType.number,
        decoration:
        InputDecoration(
          hintText: '이체 금액',
          suffixText: '원',
          contentPadding:
          const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          filled: true,
          fillColor:
          const Color(0xFFF9FAFB),
          border:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(
              10,
            ),
            borderSide:
            const BorderSide(
              color:
              Color(0xFFE5E7EB),
            ),
          ),
          enabledBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(
              10,
            ),
            borderSide:
            const BorderSide(
              color:
              Color(0xFFE5E7EB),
            ),
          ),
          focusedBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(
              10,
            ),
            borderSide:
            const BorderSide(
              color:
              Color(0xFF2563EB),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransferButton() {
    return ElevatedButton(
      onPressed:
      _isProcessing
          ? null
          : _transfer,
      style:
      ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor:
        const Color(0xFF111827),
        foregroundColor:
        Colors.white,
        shape:
        RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(
            10,
          ),
        ),
      ),
      child: _isProcessing
          ? const SizedBox(
        width: 19,
        height: 19,
        child:
        CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
          : const Text(
        '이체하기',
        style: TextStyle(
          fontSize: 13,
          fontWeight:
          FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildQuickButtons() {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
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
    );
  }

  Widget _quickButton(
      String label,
      VoidCallback onPressed,
      ) {
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed:
        _isProcessing
            ? null
            : onPressed,
        style:
        OutlinedButton.styleFrom(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 15,
          ),
          foregroundColor:
          const Color(0xFF374151),
          side:
          const BorderSide(
            color:
            Color(0xFFD1D5DB),
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              9,
            ),
          ),
        ),
        child: Text(
          label,
          style:
          const TextStyle(
            fontSize: 12,
            fontWeight:
            FontWeight.w800,
          ),
        ),
      ),
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
        if (account.accountName
            .trim()
            .isNotEmpty) {
          return account.accountName;
        }

        return account.accountType;
    }
  }
}