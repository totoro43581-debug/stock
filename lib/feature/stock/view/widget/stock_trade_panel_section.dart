import 'package:flutter/material.dart';

import 'package:stock/feature/stock/model/stock_holding_model.dart';
import 'package:stock/feature/stock/model/stock_item_view_model.dart';

class StockTradePanelSection extends StatelessWidget {
  final StockItemViewModel? selectedItem;
  final StockHoldingModel? selectedHolding;

  final TextEditingController quantityController;

  final double orderPrice;
  final double cash;

  final bool isBuyOrder;
  final bool isTrading;

  final VoidCallback onDecreaseQuantity;
  final VoidCallback onIncreaseQuantity;
  final VoidCallback onSetMaxQuantity;

  final VoidCallback onBuy;
  final VoidCallback onSell;

  final ValueChanged<bool> onChangeOrderType;

  const StockTradePanelSection({
    super.key,
    required this.selectedItem,
    required this.selectedHolding,
    required this.quantityController,
    required this.orderPrice,
    required this.cash,
    required this.isBuyOrder,
    required this.isTrading,
    required this.onDecreaseQuantity,
    required this.onIncreaseQuantity,
    required this.onSetMaxQuantity,
    required this.onBuy,
    required this.onSell,
    required this.onChangeOrderType,
  });

  @override
  Widget build(BuildContext context) {
    final item = selectedItem;

    final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
    final total = (orderPrice * quantity).round();
    final afterCash = (cash - total).round();

    final int maxBuyQuantity = orderPrice <= 0 ? 0 : (cash / orderPrice).floor();
    final int holdingQuantity = selectedHolding?.quantity ?? 0;
    final int maxOrderQuantity = isBuyOrder ? maxBuyQuantity : holdingQuantity;

    return Container(
      height: 540,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주문',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildOrderTab(
                label: '매수',
                selected: isBuyOrder,
                isBuyTab: true,
              ),
              const SizedBox(width: 8),
              _buildOrderTab(
                label: '매도',
                selected: !isBuyOrder,
                isBuyTab: false,
              ),
            ],
          ),

          const SizedBox(height: 14),

          _buildOrderLimitBox(
            isBuyOrder: isBuyOrder,
            cash: cash,
            holdingQuantity: holdingQuantity,
            maxOrderQuantity: maxOrderQuantity,
          ),

          const SizedBox(height: 12),

          const Text(
            '주문가격',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),

          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              item == null ? '-' : '₩ ${_formatPrice(orderPrice)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            '수량',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildQuantityButton('-', onDecreaseQuantity),
              const SizedBox(width: 6),
              _buildQuantityButton('+', onIncreaseQuantity),
              const SizedBox(width: 6),
              _buildMaxButton(onSetMaxQuantity),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderInfoRow(
                  '현재가',
                  item == null ? '-' : '₩ ${_formatPrice(item.currentPrice)}',
                ),
                _buildOrderInfoRow(
                  '선택가',
                  item == null ? '-' : '₩ ${_formatPrice(orderPrice)}',
                ),
                _buildOrderInfoRow('수량', '$quantity주'),
                _buildOrderInfoRow('최대가능', '$maxOrderQuantity주'),
                _buildOrderInfoRow('주문금액', '₩ ${_formatPrice(total)}'),
                _buildOrderInfoRow(
                  isBuyOrder ? '매수 후 현금' : '예상 입금',
                  isBuyOrder
                      ? '₩ ${_formatPrice(afterCash)}'
                      : '₩ ${_formatPrice(total)}',
                ),
              ],
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: isTrading
                  ? null
                  : isBuyOrder
                  ? onBuy
                  : onSell,
              style: ElevatedButton.styleFrom(
                backgroundColor: isBuyOrder
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(
                isBuyOrder ? '매수 주문' : '매도 주문',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderLimitBox({
    required bool isBuyOrder,
    required double cash,
    required int holdingQuantity,
    required int maxOrderQuantity,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isBuyOrder ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBuyOrder ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Column(
        children: [
          _buildOrderInfoRow(
            isBuyOrder ? '주문가능금액' : '보유수량',
            isBuyOrder ? '₩ ${_formatPrice(cash)}' : '$holdingQuantity주',
          ),
          _buildOrderInfoRow(
            isBuyOrder ? '최대 매수 가능' : '최대 매도 가능',
            '$maxOrderQuantity주',
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTab({
    required String label,
    required bool selected,
    required bool isBuyTab,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          onChangeOrderType(isBuyTab);
        },
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? isBuyTab
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626)
                : Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? isBuyTab
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityButton(
      String label,
      VoidCallback onPressed,
      ) {
    return SizedBox(
      width: 42,
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildMaxButton(VoidCallback onPressed) {
    return SizedBox(
      width: 48,
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: const Text(
          '최대',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfoRow(
      String title,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
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
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ],
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
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }
}