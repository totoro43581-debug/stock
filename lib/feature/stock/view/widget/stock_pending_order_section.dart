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
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          _buildTableHeader(),
          const SizedBox(height: 8),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          '미체결 주문',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        const Spacer(),
        Text(
          '${pendingOrders.length}건',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '구분',
              style: _headerTextStyle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              '종목',
              style: _headerTextStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '주문가',
              textAlign: TextAlign.right,
              style: _headerTextStyle,
            ),
          ),
          SizedBox(width: 20),
          SizedBox(
            width: 70,
            child: Text(
              '수량',
              textAlign: TextAlign.right,
              style: _headerTextStyle,
            ),
          ),
          SizedBox(width: 20),
          SizedBox(
            width: 110,
            child: Text(
              '시간',
              textAlign: TextAlign.center,
              style: _headerTextStyle,
            ),
          ),
          SizedBox(width: 16),
          SizedBox(
            width: 74,
            child: Text(
              '취소',
              textAlign: TextAlign.center,
              style: _headerTextStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!isLoggedIn) {
      return _buildEmptyMessage('로그인 후 표시됩니다.');
    }

    if (pendingOrders.isEmpty) {
      return _buildEmptyMessage('미체결 주문이 없습니다.');
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: pendingOrders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        return _buildPendingOrderRow(pendingOrders[index]);
      },
    );
  }

  Widget _buildPendingOrderRow(StockPendingOrderModel item) {
    final bool isBuy = item.orderType == 'buy';

    final Color pointColor =
    isBuy ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

    final String orderTypeLabel = isBuy ? '매수' : '매도';

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: pointColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  orderTypeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: pointColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    item.stockName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.stockCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₩ ${_formatPrice(item.orderPrice)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 70,
            child: Text(
              '${item.quantity}주',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 110,
            child: Text(
              _formatDateTime(item.createdAt),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 74,
            height: 28,
            child: OutlinedButton(
              onPressed: () async {
                await onCancelOrder(item.id);
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: const Color(0xFFDC2626),
                backgroundColor: const Color(0xFFFEF2F2),
                side: const BorderSide(
                  color: Color(0xFFFECACA),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '취소',
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

  Widget _buildEmptyMessage(String message) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  String _formatPrice(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
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

  static const TextStyle _headerTextStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w900,
    color: Color(0xFF64748B),
  );
}