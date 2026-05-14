import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:stock/feature/stock/model/stock_holding_model.dart';
import 'package:stock/feature/stock/model/stock_item_view_model.dart';

class StockMarketListSection extends StatefulWidget {
  final List<StockItemViewModel> items;
  final StockItemViewModel? selectedItem;
  final List<StockHoldingModel> holdings;
  final TextEditingController searchController;
  final String selectedMarketFilter;
  final String selectedSort;
  final ValueChanged<String?> onMarketChanged;
  final ValueChanged<String?> onSortChanged;
  final VoidCallback onSearchChanged;
  final void Function(StockItemViewModel item) onSelectItem;

  const StockMarketListSection({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.holdings,
    required this.searchController,
    required this.selectedMarketFilter,
    required this.selectedSort,
    required this.onMarketChanged,
    required this.onSortChanged,
    required this.onSearchChanged,
    required this.onSelectItem,
  });

  @override
  State<StockMarketListSection> createState() => _StockMarketListSectionState();
}

class _StockMarketListSectionState extends State<StockMarketListSection> {
  final ScrollController _marketListScrollController = ScrollController();

  @override
  void dispose() {
    _marketListScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 520,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '종목 리스트',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          _buildFilterCompact(),
          const SizedBox(height: 10),
          Expanded(
            child: widget.items.isEmpty
                ? const Center(
              child: Text(
                '조건에 맞는 종목이 없습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            )
                : Listener(
              onPointerSignal: (event) {
                if (event is! PointerScrollEvent) return;
                if (!_marketListScrollController.hasClients) return;

                GestureBinding.instance.pointerSignalResolver.register(
                  event,
                      (PointerSignalEvent resolvedEvent) {
                    if (resolvedEvent is! PointerScrollEvent) return;
                    if (!_marketListScrollController.hasClients) return;

                    final position =
                        _marketListScrollController.position;

                    final nextOffset =
                    (position.pixels + resolvedEvent.scrollDelta.dy)
                        .clamp(
                      position.minScrollExtent,
                      position.maxScrollExtent,
                    );

                    _marketListScrollController.jumpTo(
                      nextOffset.toDouble(),
                    );
                  },
                );
              },
              child: ListView.separated(
                controller: _marketListScrollController,
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.items.length,
                separatorBuilder: (_, __) {
                  return const Divider(
                    height: 1,
                    color: Color(0xFFF1F5F9),
                  );
                },
                itemBuilder: (context, index) {
                  return _buildMarketListRow(widget.items[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCompact() {
    return Column(
      children: [
        SizedBox(
          height: 38,
          child: TextField(
            controller: widget.searchController,
            onChanged: (_) => widget.onSearchChanged(),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: '종목명 / 코드 검색',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 18,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(
                  color: Color(0xFFE5E7EB),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(
                  color: Color(0xFFE5E7EB),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSmallSelect(
                value: widget.selectedMarketFilter,
                items: const [
                  '전체',
                  '국내주식',
                  '해외주식',
                  'ETF',
                  '테마주',
                ],
                onChanged: widget.onMarketChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallSelect(
                value: widget.selectedSort,
                items: const [
                  '이름',
                  '현재가',
                  '등락률',
                  '거래량',
                  '거래대금',
                ],
                onChanged: widget.onSortChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallSelect({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map(
                (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
              .toList(),
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketListRow(StockItemViewModel item) {
    final selected = widget.selectedItem?.code == item.code;
    final holding = _findHoldingByCode(item.code);
    final holdingQty = holding?.quantity ?? 0;

    return InkWell(
      onTap: () {
        widget.onSelectItem(item);
      },
      child: Container(
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _changeColor(item.changeRate),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.code,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '거래량 ${_formatVolume(item.tradeVolume)}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '체결강도 ${_formatTradeStrength(item.virtualBuyVolume, item.virtualSellVolume)}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _tradeStrengthColor(
                        item.virtualBuyVolume,
                        item.virtualSellVolume,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₩ ${_formatPrice(item.currentPrice)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatSignedPercent(item.changeRate)} · ${holdingQty}주',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _changeColor(item.changeRate),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '대금 ${_formatTradeAmount(item.tradeAmount)}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  StockHoldingModel? _findHoldingByCode(String code) {
    try {
      return widget.holdings.firstWhere(
            (item) => item.stockCode == code,
      );
    } catch (_) {
      return null;
    }
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

  Color _changeColor(double value) {
    if (value > 0) return const Color(0xFFDC2626);
    if (value < 0) return const Color(0xFF2563EB);
    return const Color(0xFF6B7280);
  }

  String _formatPrice(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  String _formatSignedPercent(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}%';
  }

  String _formatVolume(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  String _formatTradeAmount(double value) {
    if (value >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}억';
    }

    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(0)}만';
    }

    return value.toStringAsFixed(0);
  }

  String _formatTradeStrength(int buyVolume, int sellVolume) {
    if (sellVolume <= 0) {
      return '0%';
    }

    final strength = (buyVolume / sellVolume) * 100;
    return '${strength.toStringAsFixed(0)}%';
  }

  Color _tradeStrengthColor(int buyVolume, int sellVolume) {
    if (sellVolume <= 0) {
      return const Color(0xFF64748B);
    }

    final strength = (buyVolume / sellVolume) * 100;

    if (strength >= 120) {
      return const Color(0xFFDC2626);
    }

    if (strength <= 80) {
      return const Color(0xFF2563EB);
    }

    return const Color(0xFF64748B);
  }
}