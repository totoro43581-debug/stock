import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:stock/feature/coin/model/coin_item_model.dart';

class CoinOrderBookPanel extends StatelessWidget {
  final CoinItemModel? coin;
  final NumberFormat moneyFormat;
  final String Function(double value) formatQuantity;
  final String Function(double value) compactMoney;

  const CoinOrderBookPanel({
    super.key,
    required this.coin,
    required this.moneyFormat,
    required this.formatQuantity,
    required this.compactMoney,
  });

  @override
  Widget build(BuildContext context) {
    final CoinItemModel? selectedCoin = coin;

    if (selectedCoin == null) {
      return Container(
        decoration: _exchangePanelDecoration(),
        child: _buildEmptyText('선택된 코인이 없습니다.'),
      );
    }

    return Container(
      decoration: _exchangePanelDecoration(),
      child: Column(
        children: [
          _buildPanelTabHeader(
            left: '일반호가',
            center: '누적호가',
            right: '호가주문',
            selectedIndex: 0,
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _buildOrderBookRows(selectedCoin),
                ),
                Container(
                  width: 1,
                  color: const Color(0xFFE5E7EB),
                ),
                Expanded(
                  flex: 4,
                  child: _buildCoinSideStats(selectedCoin),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderBookRows(CoinItemModel coin) {
    final double basePrice = coin.currentPrice;

    final List<Map<String, dynamic>> askRows = [];
    final List<Map<String, dynamic>> bidRows = [];

    for (int i = 8; i >= 1; i--) {
      askRows.add({
        'price': basePrice * (1 + i * 0.0015),
        'quantity': coin.tradeVolume / (i * 20),
      });
    }

    for (int i = 1; i <= 8; i++) {
      bidRows.add({
        'price': basePrice * (1 - i * 0.0015),
        'quantity': coin.tradeVolume / (i * 17),
      });
    }

    double maxQuantity = 0;

    for (final row in [...askRows, ...bidRows]) {
      final double quantity = row['quantity'] as double;
      if (quantity > maxQuantity) {
        maxQuantity = quantity;
      }
    }

    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              for (final row in askRows)
                Expanded(
                  child: _buildOrderBookPriceRow(
                    price: row['price'] as double,
                    quantity: row['quantity'] as double,
                    maxQuantity: maxQuantity,
                    isAsk: true,
                  ),
                ),
            ],
          ),
        ),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border.symmetric(
              horizontal: BorderSide(color: Color(0xFFDDE3EA)),
            ),
          ),
          child: Row(
            children: [
              const Text(
                '현재가',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                ),
              ),
              const Spacer(),
              Text(
                moneyFormat.format(basePrice),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: coin.changeRate >= 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              for (final row in bidRows)
                Expanded(
                  child: _buildOrderBookPriceRow(
                    price: row['price'] as double,
                    quantity: row['quantity'] as double,
                    maxQuantity: maxQuantity,
                    isAsk: false,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderBookPriceRow({
    required double price,
    required double quantity,
    required double maxQuantity,
    required bool isAsk,
  }) {
    final double ratio =
    maxQuantity <= 0 ? 0 : (quantity / maxQuantity).clamp(0.08, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFF1F4F8)),
            ),
          ),
          child: Stack(
            children: [
              Align(
                alignment: isAsk ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: constraints.maxWidth * ratio,
                  height: double.infinity,
                  color: isAsk
                      ? const Color(0xFFFFE4E6)
                      : const Color(0xFFDBEAFE),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatQuantity(quantity),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    Text(
                      moneyFormat.format(price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isAsk
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCoinSideStats(CoinItemModel coin) {
    final double highPrice = coin.currentPrice * 1.035;
    final double lowPrice = coin.currentPrice * 0.968;

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSideStatRow(
            '거래량',
            '${formatQuantity(coin.tradeVolume)} ${coin.symbol}',
          ),
          _buildSideStatRow(
            '거래대금',
            compactMoney(coin.currentPrice * coin.tradeVolume),
          ),
          _buildSideStatRow('52주 최고', moneyFormat.format(highPrice)),
          _buildSideStatRow('52주 최저', moneyFormat.format(lowPrice)),
          const Spacer(),
          const Text(
            '체결강도',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: coin.changeRate >= 0 ? 0.68 : 0.38,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5E7EB),
            color: coin.changeRate >= 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }

  Widget _buildSideStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelTabHeader({
    required String left,
    required String center,
    required String right,
    required int selectedIndex,
  }) {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          _buildPanelTabItem(
            label: left,
            selected: selectedIndex == 0,
          ),
          _buildPanelTabItem(
            label: center,
            selected: selectedIndex == 1,
          ),
          _buildPanelTabItem(
            label: right,
            selected: selectedIndex == 2,
          ),
        ],
      ),
    );
  }

  Widget _buildPanelTabItem({
    required String label,
    required bool selected,
  }) {
    return Expanded(
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: selected
              ? const Border(
            bottom: BorderSide(
              color: Color(0xFF2563EB),
              width: 2,
            ),
          )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            color: selected ? const Color(0xFF111827) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyText(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  BoxDecoration _exchangePanelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFDDE3EA)),
    );
  }
}