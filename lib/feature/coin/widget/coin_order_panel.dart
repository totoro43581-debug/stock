import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:stock/feature/coin/model/coin_item_model.dart';

class CoinOrderPanel extends StatelessWidget {
  final CoinItemModel? coin;
  final String selectedTradeType;
  final TextEditingController quantityController;
  final bool isProcessing;

  final double coinAccountCash;
  final double selectedCoinHoldingQuantity;
  final double expectedOrderAmount;
  final double expectedFee;
  final double expectedTotalAmount;

  final bool canSubmitOrder;
  final String orderButtonText;

  final NumberFormat moneyFormat;
  final String Function(double value) formatQuantity;

  final ValueChanged<String> onTradeTypeChanged;
  final VoidCallback onQuantityChanged;
  final ValueChanged<double> onQuickPercent;
  final VoidCallback onSubmit;

  const CoinOrderPanel({
    super.key,
    required this.coin,
    required this.selectedTradeType,
    required this.quantityController,
    required this.isProcessing,
    required this.coinAccountCash,
    required this.selectedCoinHoldingQuantity,
    required this.expectedOrderAmount,
    required this.expectedFee,
    required this.expectedTotalAmount,
    required this.canSubmitOrder,
    required this.orderButtonText,
    required this.moneyFormat,
    required this.formatQuantity,
    required this.onTradeTypeChanged,
    required this.onQuantityChanged,
    required this.onQuickPercent,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _exchangePanelDecoration(),
      child: Column(
        children: [
          _buildPanelTabHeader(
            left: '매수',
            center: '매도',
            right: '거래내역',
            selectedIndex: selectedTradeType == 'buy' ? 0 : 1,
            onLeftTap: () {
              onTradeTypeChanged('buy');
            },
            onCenterTap: () {
              onTradeTypeChanged('sell');
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _buildOrderInfoRow(
                    label: '주문가능',
                    value: selectedTradeType == 'buy'
                        ? '${moneyFormat.format(coinAccountCash)} KRW'
                        : '${formatQuantity(selectedCoinHoldingQuantity)} ${coin?.symbol ?? ''}',
                  ),
                  const SizedBox(height: 12),
                  _buildOrderInputBox(
                    label: '주문가격',
                    value: coin == null ? '-' : moneyFormat.format(coin!.currentPrice),
                    suffix: 'KRW',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) {
                      onQuantityChanged();
                    },
                    decoration: InputDecoration(
                      labelText: '주문수량',
                      suffixText: coin?.symbol ?? '',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: selectedTradeType == 'buy'
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF2563EB),
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildQuickPercentButtons(),
                  const SizedBox(height: 12),
                  _buildOrderInputBox(
                    label: '주문총액',
                    value: moneyFormat.format(expectedOrderAmount),
                    suffix: 'KRW',
                  ),
                  const SizedBox(height: 12),
                  _buildOrderSummaryBox(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: canSubmitOrder ? onSubmit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedTradeType == 'buy'
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF2563EB),
                        disabledBackgroundColor: const Color(0xFFE5E7EB),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFF6B7280),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: isProcessing
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        orderButtonText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPercentButtons() {
    return Row(
      children: [
        _buildQuickButton('10%', 0.1),
        const SizedBox(width: 6),
        _buildQuickButton('25%', 0.25),
        const SizedBox(width: 6),
        _buildQuickButton('50%', 0.5),
        const SizedBox(width: 6),
        _buildQuickButton('100%', 1.0),
      ],
    );
  }

  Widget _buildQuickButton(String text, double percent) {
    return Expanded(
      child: SizedBox(
        height: 30,
        child: OutlinedButton(
          onPressed: isProcessing
              ? null
              : () {
            onQuickPercent(percent);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF374151),
            side: const BorderSide(color: Color(0xFFDDE3EA)),
            shape: const RoundedRectangleBorder(),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfoRow({
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
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
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderInputBox({
    required String label,
    required String value,
    required String suffix,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            suffix,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          _buildOrderSummaryRow(
            label: '주문금액',
            value: '${moneyFormat.format(expectedOrderAmount)} KRW',
          ),
          const SizedBox(height: 8),
          _buildOrderSummaryRow(
            label: '수수료',
            value: '${moneyFormat.format(expectedFee)} KRW',
          ),
          const SizedBox(height: 8),
          _buildOrderSummaryRow(
            label: selectedTradeType == 'buy' ? '총 필요금' : '예상 수령액',
            value: '${moneyFormat.format(expectedTotalAmount)} KRW',
            strong: true,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryRow({
    required String label,
    required String value,
    bool strong = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            color: const Color(0xFF6B7280),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: strong ? 13 : 12,
            fontWeight: FontWeight.w900,
            color: strong ? const Color(0xFF111827) : const Color(0xFF374151),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelTabHeader({
    required String left,
    required String center,
    required String right,
    required int selectedIndex,
    VoidCallback? onLeftTap,
    VoidCallback? onCenterTap,
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
            onTap: onLeftTap,
          ),
          _buildPanelTabItem(
            label: center,
            selected: selectedIndex == 1,
            onTap: onCenterTap,
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
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
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