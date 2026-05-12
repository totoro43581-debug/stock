import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stock/feature/stock/model/stock_trade_history_model.dart';

class StockTradeHistorySection extends StatelessWidget {
  final List<StockTradeHistoryModel> tradeHistoryItems;
  final int tradeHistoryPage;
  final int tradeHistoryPageSize;
  final bool isLoggedIn;
  final ValueChanged<int> onPageChanged;

  const StockTradeHistorySection({
    super.key,
    required this.tradeHistoryItems,
    required this.tradeHistoryPage,
    required this.tradeHistoryPageSize,
    required this.isLoggedIn,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = tradeHistoryItems.length;
    final totalPages = totalCount == 0
        ? 1
        : (totalCount / tradeHistoryPageSize).ceil();

    final safePage = tradeHistoryPage.clamp(0, totalPages - 1);
    final startIndex = safePage * tradeHistoryPageSize;
    final endIndex = min(startIndex + tradeHistoryPageSize, totalCount);

    final pageItems = totalCount == 0
        ? <StockTradeHistoryModel>[]
        : tradeHistoryItems.sublist(startIndex, endIndex);

    return Container(
      height: 580,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '최근 체결내역',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Text(
                '최신순 · ${safePage + 1} / $totalPages',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: pageItems.isEmpty
                ? Center(
                    child: Text(
                      isLoggedIn ? '거래내역이 없습니다.' : '로그인 후 표시됩니다.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  )
                : Column(
                    children: pageItems
                        .map((item) => _buildTradeHistoryRow(item))
                        .toList(),
                  ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildPageButton(
                label: '이전',
                enabled: safePage > 0,
                onPressed: () {
                  onPageChanged(safePage - 1);
                },
              ),
              const SizedBox(width: 8),
              Text(
                '${safePage + 1} / $totalPages',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              _buildPageButton(
                label: '다음',
                enabled: safePage < totalPages - 1,
                onPressed: () {
                  onPageChanged(safePage + 1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTradeHistoryRow(StockTradeHistoryModel item) {
    final isBuy = item.tradeType == 'buy';
    final tradeLabel = isBuy ? '매수' : '매도';

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              tradeLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isBuy
                    ? const Color(0xFF047857)
                    : const Color(0xFFB91C1C),
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.stockName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              '${item.quantity}주',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          SizedBox(
            width: 86,
            child: Text(
              '₩ ${_formatPrice(item.price)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              _formatDateTime(item.createdAt),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton({
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x06000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    );
  }

  String _formatPrice(num value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';

    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$month-$day $hour:$minute';
  }
}
