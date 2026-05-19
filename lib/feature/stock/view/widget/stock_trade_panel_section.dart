import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:stock/feature/stock/model/stock_holding_model.dart';
import 'package:stock/feature/stock/model/stock_item_view_model.dart';

class StockTradePanelSection extends StatelessWidget {
  final StockItemViewModel? selectedItem;
  final StockHoldingModel? selectedHolding;

  final TextEditingController quantityController;
  final TextEditingController priceController;

  final double orderPrice;
  final double cash;

  final double availableBuyCash;
  final double reservedBuyAmount;
  final int holdingQuantity;
  final int availableSellQuantity;
  final int reservedSellQuantity;

  final bool isBuyOrder;
  final bool isMarketOrder;
  final bool isTrading;

  final VoidCallback onDecreaseQuantity;
  final VoidCallback onIncreaseQuantity;
  final VoidCallback onSetMaxQuantity;

  final VoidCallback onBuy;
  final VoidCallback onSell;

  final ValueChanged<bool> onChangeOrderType;
  final ValueChanged<bool> onChangeOrderMode;
  final ValueChanged<String> onPriceChanged;

  const StockTradePanelSection({
    super.key,
    required this.selectedItem,
    required this.selectedHolding,
    required this.quantityController,
    required this.priceController,
    required this.orderPrice,
    required this.cash,
    required this.availableBuyCash,
    required this.reservedBuyAmount,
    required this.holdingQuantity,
    required this.availableSellQuantity,
    required this.reservedSellQuantity,
    required this.isBuyOrder,
    required this.isMarketOrder,
    required this.isTrading,
    required this.onDecreaseQuantity,
    required this.onIncreaseQuantity,
    required this.onSetMaxQuantity,
    required this.onBuy,
    required this.onSell,
    required this.onChangeOrderType,
    required this.onChangeOrderMode,
    required this.onPriceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final item = selectedItem;

    final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
    final total = (orderPrice * quantity).round();
    final afterCash = (availableBuyCash - total).round();

    final int maxBuyQuantity =
    orderPrice <= 0 ? 0 : (availableBuyCash / orderPrice).floor();

    final int maxOrderQuantity =
    isBuyOrder ? maxBuyQuantity : availableSellQuantity;

    final bool hasSelectedItem = item != null;
    final bool isQuantityValid = quantity > 0;
    final bool isPriceValid = orderPrice > 0;
    final bool isBuyCashEnough = total <= availableBuyCash;
    final bool isSellQuantityEnough = quantity <= availableSellQuantity;

    final bool canSubmit =
        hasSelectedItem &&
            isQuantityValid &&
            isPriceValid &&
            (isBuyOrder ? isBuyCashEnough : isSellQuantityEnough);

    final String statusText = _buildStatusText(
      hasSelectedItem: hasSelectedItem,
      isPriceValid: isPriceValid,
      isQuantityValid: isQuantityValid,
      isBuyCashEnough: isBuyCashEnough,
      isSellQuantityEnough: isSellQuantityEnough,
    );

    final String buttonText = _buildButtonText(
      canSubmit: canSubmit,
      statusText: statusText,
    );

    return Container(
      height: 580,
      padding: const EdgeInsets.all(10),
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
          const SizedBox(height: 8),

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

          const SizedBox(height: 8),

          Row(
            children: [
              _buildOrderModeTab(
                label: '지정가',
                selected: !isMarketOrder,
                isMarket: false,
              ),
              const SizedBox(width: 8),
              _buildOrderModeTab(
                label: '시장가',
                selected: isMarketOrder,
                isMarket: true,
              ),
            ],
          ),

          const SizedBox(height: 8),

          _buildOrderLimitBox(
            isBuyOrder: isBuyOrder,
            cash: cash,
            availableBuyCash: availableBuyCash,
            reservedBuyAmount: reservedBuyAmount,
            holdingQuantity: holdingQuantity,
            availableSellQuantity: availableSellQuantity,
            reservedSellQuantity: reservedSellQuantity,
            maxOrderQuantity: maxOrderQuantity,
          ),

          const SizedBox(height: 8),

          const Text(
            '주문가격',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 6),

          SizedBox(
            height: 42,
            child: TextField(
              controller: priceController,
              enabled: !isMarketOrder && item != null,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onPriceChanged,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
              decoration: InputDecoration(
                prefixText: isMarketOrder ? null : '₩ ',
                hintText: item == null
                    ? '-'
                    : isMarketOrder
                    ? '시장가 · ₩ ${_formatPrice(orderPrice)}'
                    : '지정가 입력',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: isMarketOrder
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            '수량',
            style: TextStyle(
              fontSize: 12,
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
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

          // 수정86차: 주문 패널 하단 3px overflow 방지를 위해 여백 12 → 10 축소
          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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
                  isMarketOrder ? '시장가' : '지정가',
                  item == null ? '-' : '₩ ${_formatPrice(orderPrice)}',
                ),
                _buildOrderInfoRow('수량', '$quantity주'),
                _buildOrderInfoRow('최대가능', '$maxOrderQuantity주'),
                _buildOrderInfoRow('주문금액', '₩ ${_formatPrice(total)}'),
                _buildOrderInfoRow(
                  isBuyOrder ? '주문 후 가능현금' : '예상 입금',
                  isBuyOrder
                      ? '₩ ${_formatPrice(afterCash)}'
                      : '₩ ${_formatPrice(total)}',
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          _buildStatusBox(
            canSubmit: canSubmit,
            statusText: statusText,
          ),

          // 수정86차: 주문 패널 하단 3px overflow 방지를 위해 여백 6 → 4 축소
          const SizedBox(height: 4),

          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: isTrading || !canSubmit
                  ? null
                  : isBuyOrder
                  ? onBuy
                  : onSell,
              style: ElevatedButton.styleFrom(
                backgroundColor: isBuyOrder
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF94A3B8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(
                buttonText,
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

  String _buildStatusText({
    required bool hasSelectedItem,
    required bool isPriceValid,
    required bool isQuantityValid,
    required bool isBuyCashEnough,
    required bool isSellQuantityEnough,
  }) {
    if (!hasSelectedItem) return '종목을 선택해주세요.';
    if (!isPriceValid) return '주문가격을 입력해주세요.';
    if (!isQuantityValid) return '수량은 1주 이상 입력해주세요.';
    if (isBuyOrder && !isBuyCashEnough) return '주문 가능 현금 부족';
    if (!isBuyOrder && !isSellQuantityEnough) return '매도 가능 수량 부족';
    return isBuyOrder ? '매수 가능' : '매도 가능';
  }

  String _buildButtonText({
    required bool canSubmit,
    required String statusText,
  }) {
    if (isTrading) return '처리 중...';
    if (!canSubmit) return statusText;
    return isBuyOrder ? '매수 주문' : '매도 주문';
  }

  Widget _buildStatusBox({
    required bool canSubmit,
    required String statusText,
  }) {
    final Color bgColor =
    canSubmit ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final Color borderColor =
    canSubmit ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA);
    final Color textColor =
    canSubmit ? const Color(0xFF047857) : const Color(0xFFB91C1C);

    return Container(
      width: double.infinity,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
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

  Widget _buildOrderModeTab({
    required String label,
    required bool selected,
    required bool isMarket,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          onChangeOrderMode(isMarket);
        },
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? const Color(0xFF111827)
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

  Widget _buildOrderLimitBox({
    required bool isBuyOrder,
    required double cash,
    required double availableBuyCash,
    required double reservedBuyAmount,
    required int holdingQuantity,
    required int availableSellQuantity,
    required int reservedSellQuantity,
    required int maxOrderQuantity,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isBuyOrder ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBuyOrder
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFFECACA),
        ),
      ),
      child: Column(
        children: [
          if (isBuyOrder) ...[
            _buildOrderInfoRow(
              '보유현금',
              '₩ ${_formatPrice(cash)}',
            ),
            _buildOrderInfoRow(
              '예약금',
              '₩ ${_formatPrice(reservedBuyAmount)}',
            ),
            _buildOrderInfoRow(
              '주문가능금액',
              '₩ ${_formatPrice(availableBuyCash)}',
            ),
            _buildOrderInfoRow(
              '최대 매수 가능',
              '$maxOrderQuantity주',
            ),
          ] else ...[
            _buildOrderInfoRow(
              '보유수량',
              '$holdingQuantity주',
            ),
            _buildOrderInfoRow(
              '예약수량',
              '$reservedSellQuantity주',
            ),
            _buildOrderInfoRow(
              '매도가능수량',
              '$availableSellQuantity주',
            ),
            _buildOrderInfoRow(
              '최대 매도 가능',
              '$maxOrderQuantity주',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuantityButton(String label, VoidCallback onPressed) {
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
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                height: 1.05,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              height: 1.05,
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