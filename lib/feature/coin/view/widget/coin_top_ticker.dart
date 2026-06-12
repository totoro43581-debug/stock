import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:stock/feature/coin/model/coin_item_model.dart';

class CoinTopTicker extends StatelessWidget {
  final CoinItemModel? coin;
  final double coinAccountCash;
  final NumberFormat moneyFormat;
  final String Function(double value) compactMoney;

  const CoinTopTicker({
    super.key,
    required this.coin,
    required this.coinAccountCash,
    required this.moneyFormat,
    required this.compactMoney,
  });

  @override
  Widget build(BuildContext context) {
    final CoinItemModel? selectedCoin = coin;
    final bool isUp = (selectedCoin?.changeRate ?? 0) >= 0;
    final Color priceColor =
    isUp ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

    return Container(
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: _exchangePanelDecoration(),
      child: selectedCoin == null
          ? const Center(
        child: Text(
          '선택된 코인이 없습니다.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7280),
          ),
        ),
      )
          : Row(
        children: [
          Expanded(
            flex: 4,
            child: _buildTickerMainInfo(
              coin: selectedCoin,
              priceColor: priceColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 6,
            child: _buildTickerStats(
              coin: selectedCoin,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTickerMainInfo({
    required CoinItemModel coin,
    required Color priceColor,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Icon(
            Icons.currency_bitcoin_rounded,
            color: Color(0xFFF97316),
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            coin.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          coin.symbol,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'KRW 마켓 · 가상 코인',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    moneyFormat.format(coin.currentPrice),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: priceColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${coin.changeRate >= 0 ? '+' : ''}${coin.changeRate.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: priceColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTickerStats({
    required CoinItemModel coin,
  }) {
    final double highPrice = coin.currentPrice * 1.035;
    final double lowPrice = coin.currentPrice * 0.968;
    final double tradeAmount = coin.currentPrice * coin.tradeVolume;

    return Row(
      children: [
        Expanded(
          child: _buildTickerStatBox(
            label: '투자 가능금',
            value: '₩ ${moneyFormat.format(coinAccountCash)}',
            valueColor: const Color(0xFFF97316),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTickerStatBox(
            label: '고가',
            value: moneyFormat.format(highPrice),
            valueColor: const Color(0xFFDC2626),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTickerStatBox(
            label: '저가',
            value: moneyFormat.format(lowPrice),
            valueColor: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTickerStatBox(
            label: '거래대금',
            value: _formatTradeAmount(tradeAmount),
            valueColor: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildTickerStatBox({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
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

  BoxDecoration _exchangePanelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFDDE3EA)),
    );
  }
}