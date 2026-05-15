import 'package:flutter/material.dart';

class StockSummarySection extends StatelessWidget {
  final double totalAsset;
  final double cash;
  final double totalStockValue;
  final double totalProfitAmount;
  final double totalProfitRate;
  final bool isWalletLoading;

  const StockSummarySection({
    super.key,
    required this.totalAsset,
    required this.cash,
    required this.totalStockValue,
    required this.totalProfitAmount,
    required this.totalProfitRate,
    required this.isWalletLoading,
  });

  static const double _radius = 18;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _buildSummaryCard(
        title: '총 자산',
        value: '₩ ${_formatPrice(totalAsset)}',
        subValue: '현금 + 주식 평가금',
        valueColor: const Color(0xFF111827),
      ),
      _buildSummaryCard(
        title: '보유 현금',
        value: '₩ ${_formatPrice(cash)}',
        subValue: isWalletLoading ? '지갑 불러오는 중' : '거래 가능 현금',
        valueColor: const Color(0xFF111827),
      ),
      _buildSummaryCard(
        title: '주식 평가금',
        value: '₩ ${_formatPrice(totalStockValue)}',
        subValue: '보유 종목 현재가 기준',
        valueColor: const Color(0xFF111827),
      ),
      _buildSummaryCard(
        title: '총 손익',
        value: '${_formatSignedPrice(totalProfitAmount)}원',
        subValue: _formatSignedPercent(totalProfitRate),
        valueColor: _changeColor(totalProfitAmount),
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subValue,
    required Color valueColor,
  }) {
    return Container(
      height: 124,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              height: 1.0,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_radius),
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

  String _formatSignedPrice(num value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${_formatPrice(value)}';
  }

  String _formatSignedPercent(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}%';
  }
}