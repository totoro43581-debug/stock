import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:stock/feature/coin/model/coin_item_model.dart';

class CoinMarketPanel extends StatefulWidget {
  final double height;
  final List<CoinItemModel> coins;
  final CoinItemModel? selectedCoin;
  final Set<String> holdingCoinCodes;
  final Set<String> favoriteCoinCodes;
  final NumberFormat moneyFormat;
  final String Function(double value) compactMoney;
  final ValueChanged<CoinItemModel> onCoinSelected;
  final Future<void> Function(CoinItemModel coin) onFavoriteToggle;

  const CoinMarketPanel({
    super.key,
    required this.height,
    required this.coins,
    required this.selectedCoin,
    required this.holdingCoinCodes,
    required this.favoriteCoinCodes,
    required this.moneyFormat,
    required this.compactMoney,
    required this.onCoinSelected,
    required this.onFavoriteToggle,
  });

  @override
  State<CoinMarketPanel> createState() => _CoinMarketPanelState();
}

class _CoinMarketPanelState extends State<CoinMarketPanel> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedMarketTab = 'KRW';
  bool _isFavoriteProcessing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CoinItemModel> get _filteredCoins {
    final String keyword = _searchController.text.trim().toLowerCase();

    List<CoinItemModel> result = widget.coins;

    if (_selectedMarketTab == '보유') {
      result = result
          .where((coin) => widget.holdingCoinCodes.contains(coin.code))
          .toList();
    } else if (_selectedMarketTab == '관심') {
      result = result
          .where((coin) => widget.favoriteCoinCodes.contains(coin.code))
          .toList();
    } else {
      result = result.where((coin) => coin.market == _selectedMarketTab).toList();
    }

    if (keyword.isNotEmpty) {
      result = result.where((coin) {
        final String name = coin.name.toLowerCase();
        final String symbol = coin.symbol.toLowerCase();
        final String code = coin.code.toLowerCase();

        return name.contains(keyword) ||
            symbol.contains(keyword) ||
            code.contains(keyword);
      }).toList();
    }

    result.sort((a, b) {
      final double aAmount = a.currentPrice * a.tradeVolume;
      final double bAmount = b.currentPrice * b.tradeVolume;

      return bAmount.compareTo(aAmount);
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final List<CoinItemModel> filteredCoins = _filteredCoins;

    return Container(
      height: widget.height,
      decoration: _exchangePanelDecoration(),
      child: Column(
        children: [
          _buildMarketSearchHeader(),
          _buildMarketTabHeader(),
          _buildMarketTableHeader(),
          Expanded(
            child: filteredCoins.isEmpty
                ? _buildEmptyText(_emptyMessage)
                : ListView.separated(
              physics: const ClampingScrollPhysics(),
              itemCount: filteredCoins.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: Color(0xFFE5E7EB),
              ),
              itemBuilder: (context, index) {
                return _buildMarketRow(filteredCoins[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  String get _emptyMessage {
    if (_searchController.text.trim().isNotEmpty) {
      return '검색 결과가 없습니다.';
    }

    if (_selectedMarketTab == '보유') {
      return '보유 중인 코인이 없습니다.';
    }

    if (_selectedMarketTab == '관심') {
      return '관심 코인이 없습니다.';
    }

    return '등록된 코인 종목이 없습니다.';
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
            child: SizedBox(
              height: 34,
              child: TextField(
                controller: _searchController,
                onChanged: (_) {
                  setState(() {});
                },
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: '코인명/심볼검색',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 0,
                  ),
                  suffixIcon: _searchController.text.trim().isEmpty
                      ? const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Color(0xFF2563EB),
                  )
                      : IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF6B7280),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
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
      child: Row(
        children: [
          _buildMarketTabText('KRW'),
          _buildMarketTabText('BTC'),
          _buildMarketTabText('USDT'),
          _buildMarketTabText('보유'),
          _buildMarketTabText('관심'),
        ],
      ),
    );
  }

  Widget _buildMarketTabText(String text) {
    final bool selected = _selectedMarketTab == text;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMarketTab = text;
          });
        },
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
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              color:
              selected ? const Color(0xFF2563EB) : const Color(0xFF374151),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketTableHeader() {
    return Container(
      height: 32,
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
            flex: 42,
            child: Text(
              '한글명',
              style: _headerSmallStyle,
            ),
          ),
          Expanded(
            flex: 58,
            child: Text(
              '현재가 / 등락률 / 거래대금',
              textAlign: TextAlign.right,
              style: _headerSmallStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketRow(CoinItemModel coin) {
    final bool isSelected = widget.selectedCoin?.code == coin.code;
    final bool isFavorite = widget.favoriteCoinCodes.contains(coin.code);
    final bool isUp = coin.changeRate >= 0;
    final Color rateColor =
    isUp ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

    final double tradeAmount = coin.currentPrice * coin.tradeVolume;

    return InkWell(
      onTap: () {
        widget.onCoinSelected(coin);
      },
      child: Container(
        height: 70,
        color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              flex: 42,
              child: Row(
                children: [
                  InkWell(
                    onTap: _isFavoriteProcessing
                        ? null
                        : () async {
                      setState(() {
                        _isFavoriteProcessing = true;
                      });

                      try {
                        await widget.onFavoriteToggle(coin);
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isFavoriteProcessing = false;
                          });
                        }
                      }
                    },
                    child: Icon(
                      isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 16,
                      color: isFavorite
                          ? const Color(0xFFF97316)
                          : const Color(0xFF9CA3AF),
                    ),
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
                        const SizedBox(height: 3),
                        Text(
                          '${coin.symbol}/${coin.market}',
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
              flex: 58,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.moneyFormat.format(coin.currentPrice),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: rateColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${isUp ? '+' : ''}${coin.changeRate.toStringAsFixed(2)}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: rateColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '거래대금 ${_formatTradeAmount(tradeAmount)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7280),
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

  String _formatTradeAmount(double value) {
    if (value >= 10000000000000000) {
      final double gyeong = value / 10000000000000000;
      final int gyeongInt = gyeong.floor();

      final double remainAfterGyeong =
          value - (gyeongInt * 10000000000000000);
      final int joInt = (remainAfterGyeong / 1000000000000).floor();

      if (joInt > 0) {
        return '${widget.moneyFormat.format(gyeongInt)}경 ${widget.moneyFormat.format(joInt)}조';
      }

      return '${widget.moneyFormat.format(gyeongInt)}경';
    }

    if (value >= 1000000000000) {
      final double jo = value / 1000000000000;

      if (jo >= 1000) {
        return '${widget.moneyFormat.format(jo.round())}조';
      }

      return '${_trimDecimal(jo, 1)}조';
    }

    if (value >= 100000000) {
      final double eok = value / 100000000;

      if (eok >= 1000) {
        return '${widget.moneyFormat.format(eok.round())}억';
      }

      return '${_trimDecimal(eok, 1)}억';
    }

    if (value >= 10000) {
      final double man = value / 10000;
      return '${widget.moneyFormat.format(man.round())}만';
    }

    return widget.moneyFormat.format(value.round());
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