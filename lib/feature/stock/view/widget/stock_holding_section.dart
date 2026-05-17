import 'package:flutter/material.dart';

import 'package:stock/feature/stock/model/stock_holding_model.dart';
import 'package:stock/feature/stock/model/stock_item_view_model.dart';

class StockHoldingSection extends StatelessWidget {
  final List<StockHoldingModel> holdingItems;
  final List<StockItemViewModel> marketItems;
  final bool isLoggedIn;
  final void Function(StockItemViewModel item) onSelectHolding;

  const StockHoldingSection({
    super.key,
    required this.holdingItems,
    required this.marketItems,
    required this.isLoggedIn,
    required this.onSelectHolding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 보유종목',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          if (!isLoggedIn)
            _buildEmptyMessage('로그인 후 보유종목이 표시됩니다.')
          else if (holdingItems.isEmpty)
            _buildEmptyMessage('보유종목이 없습니다.')
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: holdingItems.map((holding) {
                final marketItem = _findMarketItemByCode(holding.stockCode);

                return _buildHoldingCard(
                  holding: holding,
                  marketItem: marketItem,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildHoldingCard({
    required StockHoldingModel holding,
    required StockItemViewModel? marketItem,
  }) {
    final currentPrice = marketItem?.currentPrice ?? holding.averagePrice;
    final evaluationAmount = currentPrice * holding.quantity;
    final buyAmount = holding.averagePrice * holding.quantity;
    final profitAmount = evaluationAmount - buyAmount;
    final profitRate = buyAmount <= 0 ? 0 : (profitAmount / buyAmount) * 100;
    final profitColor = _changeColor(profitAmount);

    return InkWell(
      onTap: marketItem == null
          ? null
          : () {
        onSelectHolding(marketItem);
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildDot(profitAmount),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    holding.stockName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Text(
                  '${profitAmount >= 0 ? '+' : ''}${_formatPrice(profitAmount)}원',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: profitColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  '보유 ${holding.quantity}주',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                Text(
                  '${profitRate >= 0 ? '+' : ''}${profitRate.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: profitColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _buildInfoRow(
              title: '평균단가',
              value: '₩ ${_formatPrice(holding.averagePrice)}',
            ),
            _buildInfoRow(
              title: '현재가',
              value: '₩ ${_formatPrice(currentPrice)}',
            ),
            _buildInfoRow(
              title: '평가금',
              value: '₩ ${_formatPrice(evaluationAmount)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(num value) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _changeColor(value),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildEmptyMessage(String message) {
    return Container(
      width: double.infinity,
      height: 64,
      alignment: Alignment.center,
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  StockItemViewModel? _findMarketItemByCode(String code) {
    try {
      return marketItems.firstWhere((item) => item.code == code);
    } catch (_) {
      return null;
    }
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

  Color _changeColor(num value) {
    if (value > 0) return const Color(0xFFDC2626);
    if (value < 0) return const Color(0xFF2563EB);
    return const Color(0xFF6B7280);
  }

  String _formatPrice(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }
}