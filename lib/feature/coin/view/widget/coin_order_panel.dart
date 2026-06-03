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

  static const Color _borderColor = Color(0xFFDDE3EA);
  static const Color _lineColor = Color(0xFFE5E7EB);
  static const Color _boxBg = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMid = Color(0xFF374151);
  static const Color _textLight = Color(0xFF6B7280);
  static const Color _red = Color(0xFFDC2626);
  static const Color _blue = Color(0xFF2563EB);

  bool get _isBuy => selectedTradeType == 'buy';

  Color get _tradeColor {
    return _isBuy ? _red : _blue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          _buildTabHeader(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double bodyHeight = constraints.maxHeight;

                final bool compact = bodyHeight < 390;
                final double paddingY = compact ? 8 : 12;
                final double gap = compact ? 6 : 9;
                final double buttonHeight = compact ? 40 : 46;
                final double percentHeight = compact ? 28 : 32;

                final double rowHeight =
                ((bodyHeight -
                    (paddingY * 2) -
                    buttonHeight -
                    percentHeight -
                    (gap * 6)) *
                    0.145)
                    .clamp(36, 48);

                final double summaryHeight =
                    bodyHeight -
                        (paddingY * 2) -
                        buttonHeight -
                        percentHeight -
                        (rowHeight * 4) -
                        (gap * 6);

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: paddingY,
                  ),
                  child: Column(
                    children: [
                      _buildReadonlyRow(
                        height: rowHeight,
                        label: '주문가능',
                        value: _isBuy
                            ? '${moneyFormat.format(coinAccountCash)} KRW'
                            : '${formatQuantity(selectedCoinHoldingQuantity)} ${coin?.symbol ?? ''}',
                        suffix: '',
                      ),
                      SizedBox(height: gap),
                      _buildReadonlyRow(
                        height: rowHeight,
                        label: '주문가격',
                        value: coin == null
                            ? '-'
                            : moneyFormat.format(coin!.currentPrice),
                        suffix: 'KRW',
                      ),
                      SizedBox(height: gap),
                      _buildQuantityField(height: rowHeight),
                      SizedBox(height: gap),
                      _buildPercentButtons(height: percentHeight),
                      SizedBox(height: gap),
                      _buildReadonlyRow(
                        height: rowHeight,
                        label: '주문총액',
                        value: moneyFormat.format(expectedOrderAmount),
                        suffix: 'KRW',
                      ),
                      SizedBox(height: gap),
                      _buildSummaryBox(
                        height: summaryHeight.clamp(82, 128),
                      ),
                      SizedBox(height: gap),
                      _buildSubmitButton(height: buttonHeight),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader() {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _borderColor),
        ),
      ),
      child: Row(
        children: [
          _buildTabButton(
            label: '매수',
            selected: _isBuy,
            selectedColor: _red,
            selectedBg: const Color(0xFFFFF1F2),
            onTap: () {
              onTradeTypeChanged('buy');
            },
          ),
          _buildTabButton(
            label: '매도',
            selected: !_isBuy,
            selectedColor: _blue,
            selectedBg: const Color(0xFFEFF6FF),
            onTap: () {
              onTradeTypeChanged('sell');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool selected,
    required Color selectedColor,
    required Color selectedBg,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.white,
            border: selected
                ? Border(
              bottom: BorderSide(
                color: selectedColor,
                width: 2,
              ),
            )
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: selected ? selectedColor : _textLight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadonlyRow({
    required double height,
    required String label,
    required String value,
    required String suffix,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _boxBg,
        border: Border.all(color: _lineColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _textLight,
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
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _textDark,
              ),
            ),
          ),
          if (suffix.isNotEmpty) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              child: Text(
                suffix,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _textLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuantityField({
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: quantityController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) {
          onQuantityChanged();
        },
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: _textDark,
        ),
        decoration: InputDecoration(
          labelText: '주문수량',
          suffixText: coin?.symbol ?? '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: _borderColor),
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: _borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: _tradeColor,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPercentButtons({
    required double height,
  }) {
    return Row(
      children: [
        _buildPercentButton('10%', 0.1, height),
        const SizedBox(width: 6),
        _buildPercentButton('25%', 0.25, height),
        const SizedBox(width: 6),
        _buildPercentButton('50%', 0.5, height),
        const SizedBox(width: 6),
        _buildPercentButton('100%', 1.0, height),
      ],
    );
  }

  Widget _buildPercentButton(
      String label,
      double percent,
      double height,
      ) {
    return Expanded(
      child: SizedBox(
        height: height,
        child: OutlinedButton(
          onPressed: isProcessing
              ? null
              : () {
            onQuickPercent(percent);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: _textMid,
            side: const BorderSide(color: _borderColor),
            shape: const RoundedRectangleBorder(),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBox({
    required double height,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: const BoxDecoration(
        color: _boxBg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryRow(
            label: '주문금액',
            value: '${moneyFormat.format(expectedOrderAmount)} KRW',
            strong: false,
          ),
          _buildSummaryRow(
            label: '수수료',
            value: '${moneyFormat.format(expectedFee)} KRW',
            strong: false,
          ),
          _buildSummaryRow(
            label: _isBuy ? '총 필요금' : '예상 수령액',
            value: '${moneyFormat.format(expectedTotalAmount)} KRW',
            strong: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required bool strong,
  }) {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                color: _textLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: strong ? 14 : 12,
                fontWeight: FontWeight.w900,
                color: strong ? _textDark : _textMid,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton({
    required double height,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: canSubmitOrder ? onSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _tradeColor,
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          foregroundColor: Colors.white,
          disabledForegroundColor: _textLight,
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
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _borderColor),
    );
  }
}