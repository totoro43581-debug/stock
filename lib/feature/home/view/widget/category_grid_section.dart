import 'package:flutter/material.dart';

class CategoryGridSection extends StatelessWidget {
  const CategoryGridSection({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 1000) crossAxisCount = 2;
        if (constraints.maxWidth < 650) crossAxisCount = 1;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.55,
          children: const [
            _CategoryCard(
              icon: Icons.show_chart_rounded,
              title: '주식',
              description: '실제 데이터를 기반으로 주식 매수/매도와 수익률을 체험합니다.',
              accentColor: Color(0xFF2563EB),
            ),
            _CategoryCard(
              icon: Icons.stacked_line_chart_rounded,
              title: 'ETF',
              description: '개별 종목이 아닌 자산 묶음 투자 구조를 경험합니다.',
              accentColor: Color(0xFF0EA5E9),
            ),
            _CategoryCard(
              icon: Icons.savings_rounded,
              title: '예금',
              description: '안정형 자산으로 예치 기간과 이자 수익을 비교합니다.',
              accentColor: Color(0xFF10B981),
            ),
            _CategoryCard(
              icon: Icons.account_balance_rounded,
              title: '적금',
              description: '월 납입 구조와 만기 수령액을 시뮬레이션합니다.',
              accentColor: Color(0xFFF59E0B),
            ),
            _CategoryCard(
              icon: Icons.apartment_rounded,
              title: '부동산',
              description: '부동산 자산 매입과 자산 비중 변화를 모의 체험합니다.',
              accentColor: Color(0xFF8B5CF6),
            ),
            _CategoryCard(
              icon: Icons.pie_chart_rounded,
              title: '리포트',
              description: '총 자산, 수익률, 자산 배분, 변화 추이를 한눈에 확인합니다.',
              accentColor: Color(0xFFEF4444),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Color.fromRGBO(
                accentColor.red,
                accentColor.green,
                accentColor.blue,
                0.12,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}