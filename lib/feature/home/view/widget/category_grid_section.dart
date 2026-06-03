import 'package:flutter/material.dart';

class CategoryGridSection extends StatelessWidget {
  const CategoryGridSection({
    super.key,
    required this.onTapSaving,
    required this.onTapStock,
    required this.onTapCoin,
    required this.onTapRealEstate,
    required this.onTapReport,
    required this.onTapBoard,
  });

  final VoidCallback onTapSaving;
  final VoidCallback onTapStock;
  final VoidCallback onTapCoin;
  final VoidCallback onTapRealEstate;
  final VoidCallback onTapReport;
  final VoidCallback onTapBoard;

  static const double _gap = 18;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        final int crossAxisCount = width >= 1180
            ? 3
            : width >= 760
            ? 2
            : 1;

        final double cardHeight = width >= 1180
            ? 270
            : width >= 760
            ? 260
            : 250;

        final List<_CategoryItem> items = [
          _CategoryItem(
            icon: Icons.savings_rounded,
            iconBackgroundColor: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF059669),
            title: '예/적금',
            description: '안정형 자산으로 예치 기간과 이자 수익을 비교합니다.',
            buttonLabel: '예/적금 열기',
            buttonColor: const Color(0xFF059669),
            onTap: onTapSaving,
          ),
          _CategoryItem(
            icon: Icons.show_chart_rounded,
            iconBackgroundColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF2563EB),
            title: '주식',
            description: '실제 데이터를 기반으로 주식 매수/매도와 수익률을 체험합니다.',
            buttonLabel: '주식 열기',
            buttonColor: const Color(0xFF2563EB),
            onTap: onTapStock,
          ),
          _CategoryItem(
            icon: Icons.currency_bitcoin_rounded,
            iconBackgroundColor: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFF97316),
            title: '코인',
            description: '코인 투자 계좌를 기반으로 가상자산 매매를 체험합니다.',
            buttonLabel: '코인 열기',
            buttonColor: const Color(0xFFF97316),
            onTap: onTapCoin,
          ),
          _CategoryItem(
            icon: Icons.apartment_rounded,
            iconBackgroundColor: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF7C3AED),
            title: '부동산',
            description: '부동산 자산 매입과 자산 증감 흐름을 모의 체험합니다.',
            buttonLabel: '부동산 열기',
            buttonColor: const Color(0xFF7C3AED),
            onTap: onTapRealEstate,
          ),
          _CategoryItem(
            icon: Icons.pie_chart_rounded,
            iconBackgroundColor: const Color(0xFFFEE2E2),
            iconColor: const Color(0xFFDC2626),
            title: '리포트',
            description: '총 자산, 수익률, 자산 배분 변화 추이를 한눈에 확인합니다.',
            buttonLabel: '리포트 열기',
            buttonColor: const Color(0xFFDC2626),
            onTap: onTapReport,
          ),
          _CategoryItem(
            icon: Icons.forum_rounded,
            iconBackgroundColor: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
            title: '자유게시판',
            description: '투자 기록, 의견, 플레이 경험을 자유롭게 공유합니다.',
            buttonLabel: '게시판 열기',
            buttonColor: const Color(0xFF0284C7),
            onTap: onTapBoard,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: _gap,
            mainAxisSpacing: _gap,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (context, index) {
            final item = items[index];

            return _CategoryCard(item: item);
          },
        );
      },
    );
  }
}

class _CategoryItem {
  const _CategoryItem({
    required this.icon,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackgroundColor;
  final Color iconColor;
  final String title;
  final String description;
  final String buttonLabel;
  final Color buttonColor;
  final VoidCallback onTap;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.item,
  });

  final _CategoryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.iconBackgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              item.icon,
              size: 28,
              color: item.iconColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 42,
            child: OutlinedButton(
              onPressed: item.onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: item.buttonColor,
                side: BorderSide(
                  color: item.buttonColor.withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(
                item.buttonLabel,
                style: const TextStyle(
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
}