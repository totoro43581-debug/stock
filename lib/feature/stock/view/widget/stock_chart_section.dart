import 'package:flutter/material.dart';

import 'package:stock/feature/stock/model/stock_candle_model.dart';
import 'package:stock/feature/stock/model/stock_item_view_model.dart';
import 'package:stock/feature/stock/view/widget/stock_price_chart.dart';

class StockChartSection extends StatelessWidget {
  final StockItemViewModel? selectedItem;
  final List<StockCandleModel> prices;
  final bool isChartLoading;
  final DateTime? lastRealtimeUpdatedAt;

  const StockChartSection({
    super.key,
    required this.selectedItem,
    required this.prices,
    required this.isChartLoading,
    required this.lastRealtimeUpdatedAt,
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
          const SizedBox(height: 12),
          Expanded(
            child: isChartLoading
                ? const Center(child: CircularProgressIndicator())
                : StockPriceChart(
              prices: prices,
              currentPrice: item?.currentPrice ?? 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeBadge() {
    final timeText = lastRealtimeUpdatedAt == null
        ? '대기 중'
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
            '실시간 · 5분 갱신 · $timeText',
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