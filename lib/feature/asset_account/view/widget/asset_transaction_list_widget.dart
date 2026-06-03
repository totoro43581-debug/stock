import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AssetTransactionListWidget extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> transactions;

  const AssetTransactionListWidget({
    super.key,
    required this.title,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.width < 760;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 14 : 18),
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
          _buildHeader(),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            _buildEmptyBox()
          else
            Column(
              children: [
                for (int i = 0; i < transactions.length; i++) ...[
                  _buildTransactionRow(
                    transaction: transactions[i],
                    isCompact: isCompact,
                  ),
                  if (i != transactions.length - 1)
                    const Divider(
                      height: 1,
                      color: Color(0xFFE5E7EB),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        const Spacer(),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '최근 ${transactions.length}건',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF4B5563),
            ),
          ),
        ),
      ],
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
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
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
    final String rowTitle = transaction['title']?.toString() ?? '-';
    final String memo = transaction['memo']?.toString() ?? '';
    final double amount = _toDouble(transaction['amount']);
    final double balanceAfter = _toDouble(transaction['balance_after']);
    final DateTime? createdAt = _toNullableDateTime(transaction['created_at']);

    final bool isDeposit = type == 'deposit';
    final Color mainColor =
    isDeposit ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    final Color chipColor =
    isDeposit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);

    if (isCompact) {
      return _buildCompactRow(
        isDeposit: isDeposit,
        mainColor: mainColor,
        chipColor: chipColor,
        reason: reason,
        rowTitle: rowTitle,
        memo: memo,
        amount: amount,
        balanceAfter: balanceAfter,
        createdAt: createdAt,
      );
    }

    return _buildWideRow(
      isDeposit: isDeposit,
      mainColor: mainColor,
      chipColor: chipColor,
      reason: reason,
      rowTitle: rowTitle,
      memo: memo,
      amount: amount,
      balanceAfter: balanceAfter,
      createdAt: createdAt,
    );
  }

  Widget _buildWideRow({
    required bool isDeposit,
    required Color mainColor,
    required Color chipColor,
    required String reason,
    required String rowTitle,
    required String memo,
    required double amount,
    required double balanceAfter,
    required DateTime? createdAt,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 64,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Row(
        children: [
          _buildTypeChip(
            isDeposit: isDeposit,
            mainColor: mainColor,
            chipColor: chipColor,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: Text(
              _transactionReasonShortLabel(reason),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF374151),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTitleMemo(
              rowTitle: rowTitle,
              reason: reason,
              memo: memo,
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 140,
            child: Text(
              '${isDeposit ? '+' : '-'}${_formatMoney(amount)}원',
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
                fontSize: 12,
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
                fontSize: 12,
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
    required bool isDeposit,
    required Color mainColor,
    required Color chipColor,
    required String reason,
    required String rowTitle,
    required String memo,
    required double amount,
    required double balanceAfter,
    required DateTime? createdAt,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTypeChip(
                isDeposit: isDeposit,
                mainColor: mainColor,
                chipColor: chipColor,
              ),
              const SizedBox(width: 8),
              Text(
                _transactionReasonShortLabel(reason),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF374151),
                ),
              ),
              const Spacer(),
              Text(
                createdAt == null ? '-' : _formatDateTime(createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTitleMemo(
            rowTitle: rowTitle,
            reason: reason,
            memo: memo,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${isDeposit ? '+' : '-'}${_formatMoney(amount)}원',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: mainColor,
                ),
              ),
              const Spacer(),
              Text(
                '잔액 ${_formatMoney(balanceAfter)}원',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required bool isDeposit,
    required Color mainColor,
    required Color chipColor,
  }) {
    return Container(
      width: 58,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isDeposit ? '입금' : '출금',
        style: TextStyle(
          fontSize: 12,
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
  }) {
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
          memo.isEmpty ? _transactionReasonLabel(reason) : memo,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  static String _transactionReasonShortLabel(String reason) {
    switch (reason) {
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
      default:
        return reason.isEmpty ? '-' : reason;
    }
  }

  static String _transactionReasonLabel(String reason) {
    switch (reason) {
      case 'point_to_asset':
        return '포인트에서 생활 현금 계좌로 입금';
      case 'asset_transfer':
        return '계좌 간 이체';
      case 'asset_to_deposit':
        return '생활 현금 계좌에서 예금으로 이동';
      case 'deposit_to_asset':
        return '예금에서 생활 현금 계좌로 입금';
      case 'asset_to_savings':
        return '생활 현금 계좌에서 적금으로 이동';
      case 'savings_to_asset':
        return '적금에서 생활 현금 계좌로 입금';
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
      default:
        return reason.isEmpty ? '-' : reason;
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
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}