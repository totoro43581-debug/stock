import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stock/feature/stock/model/stock_item_view_model.dart';

class StockOrderBookSection extends StatelessWidget {
  final StockItemViewModel? selectedItem;
  final double? selectedOrderPrice;
  final ValueChanged<double> onSelectPrice;

  const StockOrderBookSection({
    super.key,
    required this.selectedItem,
    required this.selectedOrderPrice,
    required this.onSelectPrice,
  });

  @override
  Widget build(BuildContext context) {
    final item = selectedItem;

    if (item == null) {
      return Container(
        height: 580,
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: const Center(
          child: Text(
            '호가를 표시할 종목을 선택해주세요.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    final askPrices = _buildAskPrices(item.currentPrice);
    final bidPrices = _buildBidPrices(item.currentPrice);

    final totalAskQuantity = List.generate(
      askPrices.length,
          (index) => _buildAskQuantity(item.tradeVolume, index),
    ).fold<int>(0, (sum, value) => sum + value);

    final totalBidQuantity = List.generate(
      bidPrices.length,
          (index) => _buildBidQuantity(item.tradeVolume, index),
    ).fold<int>(0, (sum, value) => sum + value);

    return Container(
      height: 580,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '호가',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Text(
                  '매도잔량 ${_formatQty(totalAskQuantity)}주',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '매수잔량 ${_formatQty(totalBidQuantity)}주',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Expanded(
            child: Column(
              children: [
                for (int i = 0; i < askPrices.length; i++)
                  Expanded(
                    child: _buildOrderBookRow(
                      label: '매도',
                      price: askPrices[i],
                      quantity: _buildAskQuantity(
                        item.tradeVolume,
                        i,
                      ),
                      isAsk: true,
                    ),
                  ),
                Container(
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                      top: BorderSide(color: Color(0xFFE5E7EB)),
                      bottom: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${item.changeRate >= 0 ? '▲' : '▼'} '
                            '${item.changeRate.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: item.changeRate >= 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₩ ${_formatPrice(item.currentPrice)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: item.changeRate >= 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
                for (int i = 0; i < bidPrices.length; i++)
                  Expanded(
                    child: _buildOrderBookRow(
                      label: '매수',
                      price: bidPrices[i],
                      quantity: _buildBidQuantity(
                        item.tradeVolume,
                        i,
                      ),
                      isAsk: false,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderBookRow({
    required String label,
    required double price,
    required int quantity,
    required bool isAsk,
  }) {
    final selected = selectedOrderPrice?.round() == price.round();

    final color = isAsk
        ? const Color(0xFFDC2626)
        : const Color(0xFF2563EB);

    return InkWell(
      onTap: () {
        onSelectPrice(price);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFF7ED)
              : isAsk
              ? const Color(0xFFFFF1F2)
              : const Color(0xFFEFF6FF),
          border: const Border(
            bottom: BorderSide(
              color: Color(0xFFFFFFFF),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '₩ ${_formatPrice(price)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: isAsk
                          ? const Color(0xFFFFE4E6)
                          : const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    width: min(quantity.toDouble(), 120),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${_formatQty(quantity)}주',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _buildAskQuantity(int tradeVolume, int level) {
    final random = Random();

    final base =
    max((tradeVolume * (8 - level) ~/ 30), 5);

    return base + random.nextInt(25);
  }

  int _buildBidQuantity(int tradeVolume, int level) {
    final random = Random();

    final base =
    max((tradeVolume * (8 - level) ~/ 28), 5);

    return base + random.nextInt(25);
  }

  List<double> _buildAskPrices(double currentPrice) {
    final tick = _priceTick(currentPrice);

    return List.generate(8, (index) {
      return currentPrice + ((8 - index) * tick);
    });
  }

  List<double> _buildBidPrices(double currentPrice) {
    final tick = _priceTick(currentPrice);

    return List.generate(8, (index) {
      final price = currentPrice - ((index + 1) * tick);

      return price < tick ? tick : price;
    });
  }

// 수정55차: 가격대별 호가 단위
  double _priceTick(double price) {
    if (price < 1000) {
      return 1;
    }

    if (price < 10000) {
      return 10;
    }

    if (price < 100000) {
      return 100;
    }

    return 1000;
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: const Color(0xFFE5E7EB),
      ),
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
        .replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  String _formatQty(int value) {
    return value
        .toString()
        .replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }
}