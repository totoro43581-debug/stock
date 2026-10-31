import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AssetTransactionListWidget extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> transactions;

  const AssetTransactionListWidget({
    super.key,
    required this.title,
    required this.transactions,
  });

  @override
  State<AssetTransactionListWidget> createState() =>
      _AssetTransactionListWidgetState();
}

class _AssetTransactionListWidgetState
    extends State<AssetTransactionListWidget> {
  static const int _defaultVisibleCount = 5;

  bool _isExpanded = false;

  List<Map<String, dynamic>> get _visibleTransactions {
    if (_isExpanded || widget.transactions.length <= _defaultVisibleCount) {
      return widget.transactions;
    }

    return widget.transactions.take(_defaultVisibleCount).toList();
  }

  @override
  void didUpdateWidget(covariant AssetTransactionListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.title != widget.title) {
      _isExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.width < 760;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),

          const SizedBox(height: 12),

          if (widget.transactions.isEmpty)
            _buildEmptyBox()
          else ...[
            Column(
              children: [
                for (int i = 0; i < _visibleTransactions.length; i++) ...[
                  _buildTransactionRow(
                    transaction: _visibleTransactions[i],
                    isCompact: isCompact,
                  ),

                  if (i != _visibleTransactions.length - 1)
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                ],
              ],
            ),

            if (widget.transactions.length > _defaultVisibleCount) ...[
              const SizedBox(height: 14),

              _buildMoreButton(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ),

        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '총 ${widget.transactions.length}건',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4B5563),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoreButton() {
    final int remainCount = widget.transactions.length - _defaultVisibleCount;

    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFF9FAFB),
          foregroundColor: const Color(0xFF374151),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isExpanded ? '접기' : '더보기 ($remainCount건)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),

            const SizedBox(width: 5),

            Icon(
              _isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBox() {
    return Container(
      width: double.infinity,
      height: 86,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Text(
        '거래내역이 없습니다.',
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildTransactionRow({
    required Map<String, dynamic> transaction,
    required bool isCompact,
  }) {
    final String type = transaction['type']?.toString() ?? '';

    final String reason = transaction['reason']?.toString() ?? '';

    final String accountType = transaction['account_type']?.toString() ?? '';

    final String rowTitle = transaction['title']?.toString() ?? '-';

    final String memo = transaction['memo']?.toString() ?? '';

    final double amount = _toDouble(transaction['amount']);

    final double balanceAfter = _toDouble(transaction['balance_after']);

    final DateTime? createdAt = _toNullableDateTime(transaction['created_at']);

    final bool isDeposit = type == 'deposit' || type == 'in';

    final bool isTransfer = type == 'transfer';

    final Color mainColor;
    final Color chipColor;

    if (isTransfer) {
      mainColor = const Color(0xFF2563EB);
      chipColor = const Color(0xFFDBEAFE);
    } else if (isDeposit) {
      mainColor = const Color(0xFF15803D);
      chipColor = const Color(0xFFDCFCE7);
    } else {
      mainColor = const Color(0xFFB91C1C);
      chipColor = const Color(0xFFFEE2E2);
    }

    if (isCompact) {
      return _buildCompactRow(
        type: type,
        isDeposit: isDeposit,
        isTransfer: isTransfer,
        mainColor: mainColor,
        chipColor: chipColor,
        accountType: accountType,
        reason: reason,
        rowTitle: rowTitle,
        memo: memo,
        amount: amount,
        balanceAfter: balanceAfter,
        createdAt: createdAt,
      );
    }

    return _buildWideRow(
      type: type,
      isDeposit: isDeposit,
      isTransfer: isTransfer,
      mainColor: mainColor,
      chipColor: chipColor,
      accountType: accountType,
      reason: reason,
      rowTitle: rowTitle,
      memo: memo,
      amount: amount,
      balanceAfter: balanceAfter,
      createdAt: createdAt,
    );
  }

  Widget _buildWideRow({
    required String type,
    required bool isDeposit,
    required bool isTransfer,
    required Color mainColor,
    required Color chipColor,
    required String accountType,
    required String reason,
    required String rowTitle,
    required String memo,
    required double amount,
    required double balanceAfter,
    required DateTime? createdAt,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _buildTypeChip(
            isDeposit: isDeposit,
            isTransfer: isTransfer,
            mainColor: mainColor,
            chipColor: chipColor,
          ),

          const SizedBox(width: 12),

          SizedBox(
            width: 96,
            child: Text(
              _transactionReasonShortLabel(reason),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF374151),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: _buildTitleMemo(
              rowTitle: rowTitle,
              reason: reason,
              memo: memo,
              accountType: accountType,
            ),
          ),

          const SizedBox(width: 14),

          SizedBox(
            width: 140,
            child: Text(
              _amountText(
                isDeposit: isDeposit,
                isTransfer: isTransfer,
                amount: amount,
              ),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: mainColor,
              ),
            ),
          ),

          const SizedBox(width: 16),

          SizedBox(
            width: 142,
            child: Text(
              '잔액 ${_formatMoney(balanceAfter)}원',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF374151),
              ),
            ),
          ),

          const SizedBox(width: 16),

          SizedBox(
            width: 96,
            child: Text(
              createdAt == null ? '-' : _formatDateTime(createdAt),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRow({
    required String type,
    required bool isDeposit,
    required bool isTransfer,
    required Color mainColor,
    required Color chipColor,
    required String accountType,
    required String reason,
    required String rowTitle,
    required String memo,
    required double amount,
    required double balanceAfter,
    required DateTime? createdAt,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    _buildTypeChip(
                      isDeposit: isDeposit,
                      isTransfer: isTransfer,
                      mainColor: mainColor,
                      chipColor: chipColor,
                    ),
                    Text(
                      _transactionReasonShortLabel(reason),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
                Text(
                  createdAt == null ? '-' : _formatDateTime(createdAt),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          _buildTitleMemo(
            rowTitle: rowTitle,
            reason: reason,
            memo: memo,
            accountType: accountType,
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  _amountText(
                    isDeposit: isDeposit,
                    isTransfer: isTransfer,
                    amount: amount,
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: mainColor,
                  ),
                ),
                Text(
                  '잔액 ${_formatMoney(balanceAfter)}원',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required bool isDeposit,
    required bool isTransfer,
    required Color mainColor,
    required Color chipColor,
  }) {
    final String label = isTransfer
        ? '이체'
        : isDeposit
        ? '입금'
        : '출금';

    return Container(
      width: 58,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: mainColor,
        ),
      ),
    );
  }

  Widget _buildTitleMemo({
    required String rowTitle,
    required String reason,
    required String memo,
    required String accountType,
  }) {
    final String accountLabel = _accountTypeLabel(accountType);

    final String detailText = memo.isEmpty
        ? _transactionReasonLabel(reason)
        : memo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rowTitle,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 3),

        Text(
          accountLabel.isEmpty ? detailText : '$accountLabel · $detailText',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  static String _amountText({
    required bool isDeposit,
    required bool isTransfer,
    required double amount,
  }) {
    if (isTransfer) {
      return '${_formatMoney(amount)}원';
    }

    return '${isDeposit ? '+' : '-'}${_formatMoney(amount)}원';
  }

  static String _accountTypeLabel(String accountType) {
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
        return '';
    }
  }

  static String _transactionReasonShortLabel(String reason) {
    switch (reason) {
      case 'loan_disbursement':
      case 'credit_loan_disbursement':
        return '대출';
      case 'loan_repayment':
      case 'credit_loan_repayment':
        return '대출상환';

      case 'point_to_asset':
        return '포인트';

      case 'asset_transfer':
        return '계좌이체';

      case 'asset_to_deposit':
      case 'deposit_to_asset':
        return '예금';

      case 'asset_to_savings':
      case 'savings_to_asset':
        return '적금';

      case 'asset_to_stock':
      case 'stock_to_asset':
      case 'stock_buy':
      case 'stock_sell':
        return '주식';

      case 'asset_to_coin':
      case 'coin_to_asset':
      case 'coin_buy':
      case 'coin_sell':
        return '코인';

      case 'asset_to_real_estate':
      case 'real_estate_to_asset':
      case 'real_estate_buy':
      case 'real_estate_sell':
        return '부동산';

      default:
        return reason.isEmpty ? '-' : '거래';
    }
  }

  static String _transactionReasonLabel(String reason) {
    switch (reason) {
      case 'loan_disbursement':
        return '예금담보대출 입금';
      case 'loan_repayment':
        return '예금담보대출 상환';
      case 'credit_loan_disbursement':
        return '신용대출 입금';
      case 'credit_loan_repayment':
        return '신용대출 상환';

      case 'point_to_asset':
        return '포인트 입금';

      case 'asset_transfer':
        return '계좌 간 이체';

      case 'asset_to_deposit':
        return '예금 입금';

      case 'deposit_to_asset':
        return '예금 출금';

      case 'asset_to_savings':
        return '적금 입금';

      case 'savings_to_asset':
        return '적금 출금';

      case 'asset_to_stock':
      case 'stock_buy':
        return '주식 매수';

      case 'stock_to_asset':
      case 'stock_sell':
        return '주식 매도';

      case 'asset_to_coin':
      case 'coin_buy':
        return '코인 매수';

      case 'coin_to_asset':
      case 'coin_sell':
        return '코인 매도';

      case 'asset_to_real_estate':
      case 'real_estate_buy':
        return '부동산 매수';

      case 'real_estate_to_asset':
      case 'real_estate_sell':
        return '부동산 매도';

      default:
        return reason.isEmpty ? '-' : '계좌 거래';
    }
  }

  static String _formatMoney(double value) {
    return NumberFormat('#,###').format(value.floor());
  }

  static String _formatDateTime(DateTime dateTime) {
    return DateFormat('MM.dd HH:mm').format(dateTime.toLocal());
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }
}
