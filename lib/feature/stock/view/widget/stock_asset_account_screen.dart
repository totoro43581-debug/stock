import 'package:flutter/material.dart';

class StockAssetAccountScreen extends StatelessWidget {
  const StockAssetAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAssetSummaryCard(),
            const SizedBox(height: 14),
            _buildAccountFlowCard(),
            const SizedBox(height: 14),
            _buildDepositSavingCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '자산계좌',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '현금, 주식 평가금, 예금, 적금을 한 곳에서 관리합니다.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildSummaryBox(
                  title: '보유 현금',
                  amount: '2,000,000원',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryBox(
                  title: '주식 평가금',
                  amount: '0원',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryBox(
                  title: '예금/적금',
                  amount: '0원',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryBox(
                  title: '총 자산',
                  amount: '2,000,000원',
                  isStrong: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({
    required String title,
    required String amount,
    bool isStrong = false,
  }) {
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isStrong ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isStrong ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isStrong ? Colors.white70 : const Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isStrong ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountFlowCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계좌 흐름',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFlowButton(
                  title: '입금',
                  subtitle: '현금 계좌 증가',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFlowButton(
                  title: '출금',
                  subtitle: '현금 계좌 감소',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFlowButton(
                  title: '예금 가입',
                  subtitle: '현금 → 예금',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFlowButton(
                  title: '적금 가입',
                  subtitle: '현금 → 적금',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowButton({
    required String title,
    required String subtitle,
  }) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositSavingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '예금 / 적금 현황',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              '아직 가입한 예금/적금 상품이 없습니다.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
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
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );
  }
}