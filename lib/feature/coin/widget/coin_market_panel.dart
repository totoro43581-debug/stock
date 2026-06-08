import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:stock/feature/coin/model/coin_item_model.dart';

class CoinMarketPanel extends StatelessWidget {
  final double height;
  final List<CoinItemModel> coins;
  final CoinItemModel? selectedCoin;
  final NumberFormat moneyFormat;
  final String Function(double value) compactMoney;
  final ValueChanged<CoinItemModel> onCoinSelected;

  const CoinMarketPanel({
    super.key,
    required this.height,
    required this.coins,
    required this.selectedCoin,
    required this.moneyFormat,
    required this.compactMoney,
    required this.onCoinSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: _exchangePanelDecoration(),
      child: Column(
        children: [
          _buildMarketSearchHeader(),
          _buildMarketTabHeader(),
          _buildMarketTableHeader(),
          Expanded(
            child: coins.isEmpty
                ? _buildEmptyText('등록된 코인 종목이 없습니다.')
                : ListView.separated(
              physics: const ClampingScrollPhysics(),
              itemCount: coins.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: Color(0xFFE5E7EB),
              ),
              itemBuilder: (context, index) {
                return _buildMarketRow(coins[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketSearchHeader() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      '코인명/심볼검색',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Color(0xFF2563EB),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.settings_rounded,
            size: 20,
            color: Color(0xFF6B7280),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketTabHeader() {
    return Container(
      height: 42,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: const Row(
        children: [
          Expanded(child: _MarketTabText('KRW', selected: true)),
          Expanded(child: _MarketTabText('BTC')),
          Expanded(child: _MarketTabText('USDT')),
          Expanded(child: _MarketTabText('보유')),
          Expanded(child: _MarketTabText('관심')),
        ],
      ),
    );
  }

  Widget _buildMarketTableHeader() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              '한글명',
              style: _headerSmallStyle,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '현재가',
              textAlign: TextAlign.right,
              style: _headerSmallStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '전일대비',
              textAlign: TextAlign.right,
              style: _headerSmallStyle,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '거래대금',
              textAlign: TextAlign.right,
              style: _headerSmallStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketRow(CoinItemModel coin) {
    final bool isSelected = selectedCoin?.code == coin.code;
    final bool isUp = coin.changeRate >= 0;
    final Color rateColor =
    isUp ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

    return InkWell(
      onTap: () {
        onCoinSelected(coin);
      },
      child: Container(
        height: 54,
        color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 16,
                    color: isSelected
                        ? const Color(0xFFF97316)
                        : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coin.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${coin.symbol}/KRW',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                moneyFormat.format(coin.currentPrice),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: rateColor,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${isUp ? '+' : ''}${coin.changeRate.toStringAsFixed(2)}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: rateColor,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                compactMoney(coin.currentPrice * coin.tradeVolume),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
            ),
          ],
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

const TextStyle _headerSmallStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w800,
  color: Color(0xFF6B7280),
);

class _MarketTabText extends StatelessWidget {
  final String text;
  final bool selected;

  const _MarketTabText(
      this.text, {
        this.selected = false,
      });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          color: selected ? const Color(0xFF2563EB) : const Color(0xFF374151),
        ),
      ),
    );
  }
}