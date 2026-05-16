import 'package:flutter/material.dart';

import 'package:stock/feature/stock/model/stock_candle_model.dart';
import 'package:stock/feature/stock/model/stock_item_view_model.dart';
import 'package:stock/feature/stock/view/widget/stock_price_chart.dart';

class StockChartSection extends StatelessWidget {
  final StockItemViewModel? selectedItem;
  final List<StockCandleModel> prices;
  final bool isChartLoading;
  final DateTime? lastRealtimeUpdatedAt;
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  const StockChartSection({
    super.key,
    required this.selectedItem,
    required this.prices,
    required this.isChartLoading,
    required this.lastRealtimeUpdatedAt,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final item = selectedItem;

    return Container(
      height: 520,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item == null ? '차트' : '${item.name} 차트',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _buildRealtimeBadge(),
            ],
          ),
          const SizedBox(height: 10),
          _buildRangeButtons(),
          const SizedBox(height: 10),
          Expanded(
            child: isChartLoading
                ? const Center(child: CircularProgressIndicator())
                : StockPriceChart(
              prices: prices,
              currentPrice: item?.currentPrice ?? 0,
              selectedRange: selectedRange,
            ),
          ),
        ],
      ),
    );
  }

  // 수정70차: 차트 범위 버튼 한 줄 통합
  Widget _buildRangeButtons() {
    final ranges = [
      '전체',
      '1분',
      '5분',
      '15분',
      '30분',
      '1시간',
      '3시간',
      '1주',
      '1개월',
      '3개월',
      '1년',
      ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final range in ranges) ...[
            _buildRangeButton(range),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildRangeButton(String range) {
    final selected = selectedRange == range;

    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: () => onRangeChanged(range),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          backgroundColor: selected ? const Color(0xFF0F172A) : Colors.white,
          foregroundColor: selected ? Colors.white : const Color(0xFF334155),
          side: BorderSide(
            color: selected ? const Color(0xFF0F172A) : const Color(0xFFE5E7EB),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          range,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildRealtimeBadge() {
    final timeText = lastRealtimeUpdatedAt == null
        ? '아직 없음'
        : '${lastRealtimeUpdatedAt!.hour.toString().padLeft(2, '0')}:'
        '${lastRealtimeUpdatedAt!.minute.toString().padLeft(2, '0')}:'
        '${lastRealtimeUpdatedAt!.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '거래량 반영 · 마지막 갱신 · $timeText',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF475569),
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
}