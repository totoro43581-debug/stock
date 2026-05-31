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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              Text(
                '최근 ${transactions.length}건',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
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
                '거래내역이 없습니다.',
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
                for (int i = 0; i < transactions.length; i++) ...[
                  _buildTransactionRow(transactions[i]),
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

  Widget _buildTransactionRow(Map<String, dynamic> transaction) {
    final String type = transaction['type']?.toString() ?? '';
    final String reason = transaction['reason']?.toString() ?? '';
    final String title = transaction['title']?.toString() ?? '-';
    final String memo = transaction['memo']?.toString() ?? '';
    final double amount = _toDouble(transaction['amount']);
    final double balanceAfter = _toDouble(transaction['balance_after']);
    final DateTime? createdAt = _toNullableDateTime(transaction['created_at']);

    final bool isDeposit = type == 'deposit';

    return Container(
      constraints: const BoxConstraints(
        minHeight: 70,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 32,
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
                    : const Color(0xFFB91C1C),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
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
          const SizedBox(width: 16),
          SizedBox(
            width: 150,
            child: Text(
              '${isDeposit ? '+' : '-'}${_formatMoney(amount)}원',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isDeposit
                    ? const Color(0xFF15803D)
                    : const Color(0xFFB91C1C),
              ),
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 150,
            child: Text(
              '잔액 ${_formatMoney(balanceAfter)}원',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF374151),
              ),
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 120,
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
        return '자산계좌에서 주식 매수';
      case 'stock_to_asset':
        return '주식 매도 후 자산계좌 입금';
      case 'asset_to_coin':
        return '자산계좌에서 코인 매수';
      case 'coin_to_asset':
        return '코인 매도 후 자산계좌 입금';
      default:
        return reason;
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