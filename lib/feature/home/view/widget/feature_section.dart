import 'package:flutter/material.dart';

class FeatureSection extends StatelessWidget {
  const FeatureSection({super.key});

  static const double _gap = 14;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDesktop = width >= 980;
        final bool isMobile = width < 620;

        final double padding = isMobile ? 18 : 24;
        final double titleSize = isMobile ? 21 : 24;

        final List<_FeatureItem> items = [
          const _FeatureItem(
            icon: Icons.account_balance_wallet_rounded,
            title: '자산계좌 중심 구조',
            description: '생활 현금, 주식 투자, 코인 투자 계좌를 분리해서 자산 흐름을 관리합니다.',
          ),
          const _FeatureItem(
            icon: Icons.savings_rounded,
            title: '예/적금 운용',
            description: '예금, 적금 가입과 납입, 중도해지, 만기수령 흐름을 체험합니다.',
          ),
          const _FeatureItem(
            icon: Icons.show_chart_rounded,
            title: '주식 매매',
            description: '주식 투자 계좌 잔액을 기준으로 매수/매도와 보유 종목을 관리합니다.',
          ),
          const _FeatureItem(
            icon: Icons.pie_chart_rounded,
            title: '리포트 확장',
            description: '자산 배분, 수익률, 기간별 변화를 한눈에 보는 구조로 확장합니다.',
          ),
        ];

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '서비스 방향',
                style: TextStyle(
                  color: const Color(0xFF111827),
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '단순 투자 게임이 아니라, 사용자가 가상의 자산을 직접 옮기고 운용하면서 자산 흐름을 이해하는 경제 시뮬레이션 플랫폼입니다.',
                style: TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 15,
                  height: 1.7,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      Expanded(
                        child: _FeatureCard(item: items[i]),
                      ),
                      if (i != items.length - 1)
                        const SizedBox(width: _gap),
                    ],
                  ],
                )
              else
                Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      _FeatureCard(item: items[i]),
                      if (i != items.length - 1)
                        const SizedBox(height: _gap),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.item,
  });

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 148),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.icon,
              size: 21,
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}