import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock/feature/wallet/model/wallet_model.dart';

class WalletSummarySection extends StatelessWidget {
  final WalletModel wallet;

  const WalletSummarySection({
    super.key,
    required this.wallet,
  });

  String _formatWon(int value) {
    return NumberFormat('#,###').format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 지갑',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '기본 지급금이 반영된 현재 보유 현금입니다.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${_formatWon(wallet.cashBalance)}원',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}