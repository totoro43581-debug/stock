import 'package:flutter/material.dart';

import 'package:stock/feature/stock/model/stock_item_view_model.dart';

class StockHeaderSection extends StatelessWidget {
  final StockItemViewModel? selectedItem;
  final VoidCallback onTapRegister;

  const StockHeaderSection({
    super.key,
    required this.selectedItem,
    required this.onTapRegister,
  });

  @override
  Widget build(BuildContext context) {
    final item = selectedItem;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: item == null
                ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '주식',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '종목을 선택하면 차트, 호가, 주문창이 표시됩니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ],
            )
                : Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0x1FFFFFFF),
                    borderRadius: BorderRadius.all(
                      Radius.circular(14),
                    ),
                  ),
                  child: Text(
                    item.name.characters.first,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.code} · ${item.market}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 28),
                Text(
                  '₩ ${_formatPrice(item.currentPrice)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: onTapRegister,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                '종목 등록',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }
}