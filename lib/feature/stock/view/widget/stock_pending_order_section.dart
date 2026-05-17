import 'package:flutter/material.dart';

import 'package:stock/feature/stock/model/stock_pending_order_model.dart';

class StockPendingOrderSection extends StatelessWidget {
  final List<StockPendingOrderModel> pendingOrders;
  final bool isLoggedIn;
  final Future<void> Function(String orderId) onCancelOrder;

  const StockPendingOrderSection({
    super.key,
    required this.pendingOrders,
    required this.isLoggedIn,
    required this.onCancelOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '미체결 주문',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Text(
                '${pendingOrders.length}건',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (!isLoggedIn)
            _buildEmptyMessage('로그인 후 표시됩니다.')
          else if (pendingOrders.isEmpty)
            _buildEmptyMessage('미체결 주문이 없습니다.')
          else
            Column(
              children: [
                for (int i = 0; i < pendingOrders.length; i++) ...[
                  _buildPendingOrderRow(pendingOrders[i]),
                  if (i != pendingOrders.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPendingOrderRow(
      StockPendingOrderModel item,
      ) {
    final bool isBuy = item.orderType == 'buy';

    final Color pointColor = isBuy
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    final Color buttonBgColor = isBuy
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFFEF2F2);

    final Color buttonBorderColor = isBuy
        ? const Color(0xFFBBF7D0)
        : const Color(0xFFFECACA);

    return Container(
      width: double.infinity,
      height: 54,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pointColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              isBuy ? '매수' : '매도',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(width: 14),

          SizedBox(
            width: 180,
            child: Text(
              item.stockName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),

          const SizedBox(width: 20),

          _buildInlineInfo(
            title: '주문가',
            value: '₩ ${_formatPrice(item.orderPrice)}',
            width: 150,
          ),

          const SizedBox(width: 20),

          _buildInlineInfo(
            title: '시간',
            value: _formatDateTime(item.createdAt),
            width: 140,
          ),

          const Spacer(),

          SizedBox(
            width: 64,
            child: Text(
              '${item.quantity}주',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF334155),
              ),
            ),
          ),

          const SizedBox(width: 18),

          SizedBox(
            width: 88,
            height: 34,
            child: OutlinedButton(
              onPressed: () async {
                await onCancelOrder(item.id);
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: const Color(0xFFDC2626),
                backgroundColor: buttonBgColor,
                side: BorderSide(
                  color: buttonBorderColor,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '주문 취소',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineInfo({
    required String title,
    required String value,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Text(
            '$title ',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessage(String message) {
    return Container(
      width: double.infinity,
      height: 64,
      alignment: Alignment.center,
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF64748B),
        ),
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

  String _formatPrice(num value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$month-$day $hour:$minute';
  }
}