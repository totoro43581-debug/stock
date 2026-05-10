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
        height: 420,
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

    return Container(
      height: 420,
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
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              children: [
                for (final price in askPrices)
                  Expanded(
                    child: _buildOrderBookRow(
                      label: '매도',
                      price: price,
                      isAsk: true,
                    ),
                  ),
                Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                      top: BorderSide(color: Color(0xFFE5E7EB)),
                      bottom: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Text(
                    '현재가 ₩ ${_formatPrice(item.currentPrice)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                for (final price in bidPrices)
                  Expanded(
                    child: _buildOrderBookRow(
                      label: '매수',
                      price: price,
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
    required bool isAsk,
  }) {
    final selected = selectedOrderPrice?.round() == price.round();
    final fakeQty = (price.round().abs() % 17) + 1;
    final color = isAsk ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

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
            const SizedBox(width: 14),
            SizedBox(
              width: 42,
              child: Text(
                '$fakeQty주',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<double> _buildAskPrices(double currentPrice) {
    return List.generate(8, (index) {
      return currentPrice + ((8 - index) * 100);
    });
  }

  List<double> _buildBidPrices(double currentPrice) {
    return List.generate(8, (index) {
      return currentPrice - ((index + 1) * 100);
    });
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
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }
}