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

  static const Color _borderColor = Color(0xFFDDE3EA);
  static const Color _lineColor = Color(0xFFF1F4F8);
  static const Color _headerBg = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMid = Color(0xFF374151);
  static const Color _textLight = Color(0xFF6B7280);
  static const Color _red = Color(0xFFDC2626);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _askBg = Color(0xFFFFE4E6);
  static const Color _bidBg = Color(0xFFDBEAFE);

  @override
  Widget build(BuildContext context) {
    final CoinItemModel? selectedCoin = coin;

    if (selectedCoin == null) {
      return Container(
        decoration: _panelDecoration(),
        child: _buildEmptyText('선택된 코인이 없습니다.'),
      );
    }

    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          _buildHeaderTabs(),
          _buildMarketSummary(selectedCoin),
          _buildColumnHeader(),
          Expanded(
            child: _buildOrderBook(selectedCoin),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTabs() {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _borderColor),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderTab('일반호가', true),
          _buildHeaderTab('누적호가', false),
          _buildHeaderTab('호가주문', false),
        ],
      ),
    );
  }

  Widget _buildHeaderTab(String label, bool selected) {
    return Expanded(
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: selected
              ? const Border(
            bottom: BorderSide(
              color: _blue,
              width: 2,
            ),
          )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            color: selected ? _textDark : _textLight,
          ),
        ),
      ),
    );
  }

  Widget _buildMarketSummary(CoinItemModel coin) {
    final double tradeAmount = coin.currentPrice * coin.tradeVolume;
    final double highPrice = coin.currentPrice * 1.035;
    final double lowPrice = coin.currentPrice * 0.968;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(
          bottom: BorderSide(color: _borderColor),
        ),
      ),
      child: Row(
        children: [
          _buildSummaryText(
            label: '거래량',
            value: '${_formatOrderQuantity(coin.tradeVolume)} ${coin.symbol}',
          ),
          _buildSummaryText(
            label: '거래대금',
            value: _formatTradeAmount(tradeAmount),
          ),
          _buildSummaryText(
            label: '고가',
            value: moneyFormat.format(highPrice),
            valueColor: _red,
          ),
          _buildSummaryText(
            label: '저가',
            value: moneyFormat.format(lowPrice),
            valueColor: _blue,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryText({
    required String label,
    required String value,
    Color valueColor = _textDark,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _textLight,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: valueColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnHeader() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white,
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '매도수량',
              style: _headerStyle,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '호가',
              textAlign: TextAlign.center,
              style: _headerStyle,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '매수수량',
              textAlign: TextAlign.right,
              style: _headerStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderBook(CoinItemModel coin) {
    final double basePrice = coin.currentPrice;

    final List<_OrderBookRowData> askRows = [];
    final List<_OrderBookRowData> bidRows = [];

    for (int i = 6; i >= 1; i--) {
      askRows.add(
        _OrderBookRowData(
          price: basePrice * (1 + i * 0.0015),
          quantity: coin.tradeVolume / (i * 20),
          isAsk: true,
        ),
      );
    }

    for (int i = 1; i <= 6; i++) {
      bidRows.add(
        _OrderBookRowData(
          price: basePrice * (1 - i * 0.0015),
          quantity: coin.tradeVolume / (i * 17),
          isAsk: false,
        ),
      );
    }

    double maxQuantity = 0;

    for (final row in [...askRows, ...bidRows]) {
      if (row.quantity > maxQuantity) {
        maxQuantity = row.quantity;
      }
    }

    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              for (final row in askRows)
                Expanded(
                  child: _buildOrderBookRow(
                    row: row,
                    maxQuantity: maxQuantity,
                  ),
                ),
            ],
          ),
        ),
        _buildCurrentPriceRow(coin),
        Expanded(
          child: Column(
            children: [
              for (final row in bidRows)
                Expanded(
                  child: _buildOrderBookRow(
                    row: row,
                    maxQuantity: maxQuantity,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentPriceRow(CoinItemModel coin) {
    final Color color = coin.changeRate >= 0 ? _red : _blue;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border.symmetric(
          horizontal: BorderSide(color: _borderColor),
        ),
      ),
      child: Row(
        children: [
          const Text(
            '현재가',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _textLight,
            ),
          ),
          const Spacer(),
          Text(
            moneyFormat.format(coin.currentPrice),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${coin.changeRate >= 0 ? '+' : ''}${coin.changeRate.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderBookRow({
    required _OrderBookRowData row,
    required double maxQuantity,
  }) {
    final double ratio =
    maxQuantity <= 0 ? 0 : (row.quantity / maxQuantity).clamp(0.08, 1.0);

    final Color priceColor = row.isAsk ? _red : _blue;
    final Color barColor = row.isAsk ? _askBg : _bidBg;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: _lineColor),
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: row.isAsk ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: ratio,
              heightFactor: 1,
              child: ColoredBox(color: barColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    row.isAsk ? _formatOrderQuantity(row.quantity) : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _textMid,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    moneyFormat.format(row.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: priceColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    row.isAsk ? '' : _formatOrderQuantity(row.quantity),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _textMid,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatOrderQuantity(double value) {
    if (value >= 100000000) {
      final double eok = value / 100000000;
      return '${_trimDecimal(eok, 1)}억';
    }

    if (value >= 10000) {
      final double man = value / 10000;
      return '${_trimDecimal(man, 1)}만';
    }

    if (value >= 1000) {
      return moneyFormat.format(value.round());
    }

    if (value >= 100) {
      return value.toStringAsFixed(1);
    }

    if (value >= 1) {
      return value.toStringAsFixed(2);
    }

    return value.toStringAsFixed(6);
  }

  String _formatTradeAmount(double value) {
    if (value >= 10000000000000000) {
      final double gyeong = value / 10000000000000000;
      return '${_trimDecimal(gyeong, 1)}경';
    }

    if (value >= 1000000000000) {
      final double jo = value / 1000000000000;
      return '${_trimDecimal(jo, 1)}조';
    }

    if (value >= 100000000) {
      final double eok = value / 100000000;
      return '${_trimDecimal(eok, 1)}억';
    }

    if (value >= 10000) {
      final double man = value / 10000;
      return '${_trimDecimal(man, 1)}만';
    }

    return moneyFormat.format(value.round());
  }

  String _trimDecimal(double value, int fractionDigits) {
    final String text = value.toStringAsFixed(fractionDigits);

    if (text.endsWith('.0')) {
      return text.substring(0, text.length - 2);
    }

    return text;
  }

  Widget _buildEmptyText(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: _textLight,
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

class _OrderBookRowData {
  final double price;
  final double quantity;
  final bool isAsk;

  const _OrderBookRowData({
    required this.price,
    required this.quantity,
    required this.isAsk,
  });
}

const TextStyle _headerStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w800,
  color: Color(0xFF6B7280),
);