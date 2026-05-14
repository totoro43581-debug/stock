import 'package:flutter/material.dart';

import 'package:stock/feature/stock/model/stock_item_view_model.dart';

class StockTickLogSection extends StatelessWidget {
  final List<StockItemViewModel> items;

  const StockTickLogSection({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final logs = [...items]
      ..sort((a, b) => b.tradeVolume.compareTo(a.tradeVolume));

    final visibleLogs = logs.take(8).toList();

    return Container(
      height: 220,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '실시간 체결',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: visibleLogs.isEmpty
                ? const Center(
              child: Text(
                '체결 로그가 없습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            )
                : ListView.separated(
              itemCount: visibleLogs.length,
              separatorBuilder: (_, __) {
                return const Divider(
                  height: 1,
                  color: Color(0xFFF1F5F9),
                );
              },
              itemBuilder: (context, index) {
                return _buildLogRow(visibleLogs[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogRow(StockItemViewModel item) {
    final isUp = item.changeRate >= 0;
    final color = isUp ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

    return SizedBox(
      height: 34,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              _nowText(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          SizedBox(
            width: 82,
            child: Text(
              '₩ ${_formatPrice(item.currentPrice)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              '${item.changeRate >= 0 ? '+' : ''}${item.changeRate.toStringAsFixed(2)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              '${_formatVolume(item.tradeVolume)}주',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
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

  String _nowText() {
    final now = DateTime.now();

    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
  }

  String _formatPrice(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  String _formatVolume(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }
}