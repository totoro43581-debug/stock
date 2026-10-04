import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model/asset_account_model.dart';
import '../repository/asset_account_repository.dart';
import 'widget/asset_account_transfer_widget.dart';
import 'widget/asset_transaction_list_widget.dart';

class AssetAccountScreen extends StatefulWidget {
  const AssetAccountScreen({
    super.key,
  });

  @override
  State<AssetAccountScreen> createState() =>
      _AssetAccountScreenState();
}

class _AssetAccountScreenState
    extends State<AssetAccountScreen> {
  final AssetAccountRepository _repository =
  AssetAccountRepository();

  final NumberFormat _moneyFormat =
  NumberFormat('#,###');

  bool _isLoading = true;

  List<AssetAccountModel> _accounts = [];

  List<Map<String, dynamic>> _transactions = [];

  String _selectedAccountType = 'all';

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await _repository.ensureUserAssetAccounts();

      final accountRows =
      await _repository.fetchUserAssetAccounts();

      final transactionRows =
      await _repository.fetchAssetAccountTransactions(
        limit: 50,
      );

      if (!mounted) return;

      setState(() {
        _accounts = accountRows
            .map(
          AssetAccountModel.fromMap,
        )
            .toList();

        _transactions = transactionRows;

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

  Future<void> _refreshAfterTransfer() async {
    try {
      final accountRows =
      await _repository.fetchUserAssetAccounts();

      final transactionRows =
      await _repository.fetchAssetAccountTransactions(
        limit: 50,
      );

      if (!mounted) return;

      setState(() {
        _accounts = accountRows
            .map(
          AssetAccountModel.fromMap,
        )
            .toList();

        _transactions = transactionRows;
      });
    } catch (e) {
      debugPrint(
        '계좌이체 후 새로고침 실패: $e',
      );
    }
  }

  List<Map<String, dynamic>>
  get _filteredTransactions {
    if (_selectedAccountType == 'all') {
      return _transactions;
    }

    return _transactions
        .where(
          (transaction) =>
      transaction['account_type']
          ?.toString() ==
          _selectedAccountType,
    )
        .toList();
  }

  double get _totalCashBalance {
    double total = 0;

    for (final account in _accounts) {
      if (!account.isActive) {
        continue;
      }

      total += account.cashBalance;
    }

    return total;
  }

  AssetAccountModel? _findAccount(
      String accountType,
      ) {
    for (final account in _accounts) {
      if (account.accountType ==
          accountType) {
        return account;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompact =
        MediaQuery.of(context).size.width < 760;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      color: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        physics:
        const ClampingScrollPhysics(),
        padding: EdgeInsets.all(
          isCompact ? 12 : 20,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(
              maxWidth: 1400,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _buildTopSummary(),

                const SizedBox(height: 16),

                _buildAccountCards(
                  isCompact: isCompact,
                ),

                const SizedBox(height: 16),

                AssetAccountTransferWidget(
                  onTransferCompleted:
                  _refreshAfterTransfer,
                ),

                const SizedBox(height: 16),

                _buildTransactionFilter(),

                const SizedBox(height: 10),

                AssetTransactionListWidget(
                  title:
                  _transactionTitle(),
                  transactions:
                  _filteredTransactions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSummary() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            '계좌',
            style: TextStyle(
              fontSize: 24,
              fontWeight:
              FontWeight.w900,
              color:
              Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            '생활 현금 및 투자계좌를 관리합니다.',
            style: TextStyle(
              fontSize: 13,
              fontWeight:
              FontWeight.w700,
              color:
              Color(0xFF6B7280),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            '전체 계좌 현금',
            style: TextStyle(
              fontSize: 12,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF6B7280),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '${_moneyFormat.format(_totalCashBalance.floor())}원',
            style: const TextStyle(
              fontSize: 30,
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

  Widget _buildAccountCards({
    required bool isCompact,
  }) {
    final accountTypes = [
      'bank',
      'stock',
      'coin',
      'real_estate',
    ];

    if (isCompact) {
      return Column(
        children: [
          for (
          int i = 0;
          i < accountTypes.length;
          i++
          ) ...[
            _buildAccountCard(
              accountTypes[i],
            ),

            if (i !=
                accountTypes.length - 1)
              const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (
        int i = 0;
        i < accountTypes.length;
        i++
        ) ...[
          Expanded(
            child: _buildAccountCard(
              accountTypes[i],
            ),
          ),

          if (i !=
              accountTypes.length - 1)
            const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _buildAccountCard(
      String accountType,
      ) {
    final account =
    _findAccount(accountType);

    return Container(
      constraints: const BoxConstraints(
        minHeight: 120,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
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
            _accountTypeLabel(
              accountType,
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight:
              FontWeight.w900,
              color:
              Color(0xFF4B5563),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            account == null
                ? '0원'
                : '${_moneyFormat.format(account.cashBalance.floor())}원',
            style: const TextStyle(
              fontSize: 22,
              fontWeight:
              FontWeight.w900,
              color:
              Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            account == null
                ? '계좌 없음'
                : account.accountNumber
                .trim()
                .isEmpty
                ? account.accountName
                : account.accountNumber,
            style: const TextStyle(
              fontSize: 12,
              fontWeight:
              FontWeight.w700,
              color:
              Color(0xFF9CA3AF),
            ),
            overflow:
            TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionFilter() {
    const filters = [
      'all',
      'bank',
      'stock',
      'coin',
      'real_estate',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in filters)
          ChoiceChip(
            label: Text(
              _filterLabel(type),
            ),
            selected:
            _selectedAccountType ==
                type,
            onSelected: (_) {
              setState(() {
                _selectedAccountType =
                    type;
              });
            },
          ),
      ],
    );
  }

  String _transactionTitle() {
    switch (_selectedAccountType) {
      case 'bank':
        return '생활 현금 거래내역';

      case 'stock':
        return '주식 투자 거래내역';

      case 'coin':
        return '코인 투자 거래내역';

      case 'real_estate':
        return '부동산 투자 거래내역';

      default:
        return '전체 거래내역';
    }
  }

  String _filterLabel(
      String accountType,
      ) {
    switch (accountType) {
      case 'all':
        return '전체';

      case 'bank':
        return '생활';

      case 'stock':
        return '주식';

      case 'coin':
        return '코인';

      case 'real_estate':
        return '부동산';

      default:
        return accountType;
    }
  }

  String _accountTypeLabel(
      String accountType,
      ) {
    switch (accountType) {
      case 'bank':
        return '생활 현금';

      case 'stock':
        return '주식 투자';

      case 'coin':
        return '코인 투자';

      case 'real_estate':
        return '부동산 투자';

      default:
        return accountType;
    }
  }
}