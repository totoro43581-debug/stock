import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HeroSection extends StatelessWidget {
  final User? user;

  const HeroSection({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 수정1차: 최초 렌더링 overflow 방지를 위해 폭에 따라 간격/폰트 축소
        final bool isCompactWide = constraints.maxWidth < 1180;

        final double outerPadding = isCompactWide ? 24 : 32;
        final double titleFontSize = isCompactWide ? 36 : 42;
        final double bodyFontSize = isCompactWide ? 15 : 17;
        final double sectionGap = isCompactWide ? 16 : 22;
        final double bodyGap = isCompactWide ? 14 : 18;
        final double tagGap = isCompactWide ? 8 : 10;
        final double rightCardPadding = isCompactWide ? 16 : 20;
        final double rightTitleFontSize = isCompactWide ? 18 : 20;
        final double previewGap = isCompactWide ? 10 : 12;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(outerPadding),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F172A),
                Color(0xFF1E293B),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '자산을 이해하고 운영해보는 경제 시뮬레이션',
                        style: TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    Text(
                      '주식만이 아니라\n예금, ETF, 부동산까지',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleFontSize,
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: bodyGap),
                    Text(
                      user == null
                          ? '가상의 자산으로 다양한 경제 활동을 체험하고,\n자산 배분과 수익률 변화를 직접 비교해볼 수 있습니다.'
                          : '${user?.email ?? ''} 님, 현재 로그인된 상태입니다.\n다음 단계에서 내 자산 대시보드와 실제 상품별 기능을 연결합니다.',
                      style: TextStyle(
                        color: const Color(0xFFD1D5DB),
                        fontSize: bodyFontSize,
                        height: 1.6,
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    Wrap(
                      spacing: tagGap,
                      runSpacing: tagGap,
                      children: const [
                        _HeroTag(text: '주식'),
                        _HeroTag(text: 'ETF'),
                        _HeroTag(text: '예금'),
                        _HeroTag(text: '적금'),
                        _HeroTag(text: '부동산'),
                        _HeroTag(text: '자산 리포트'),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: isCompactWide ? 20 : 24),
              Expanded(
                flex: 3,
                child: Container(
                  padding: EdgeInsets.all(rightCardPadding),
                  decoration: BoxDecoration(
                    color: const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '미리보기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: rightTitleFontSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: isCompactWide ? 14 : 18),
                      const _PreviewRow(label: '총 자산', value: '₩ 100,000,000'),
                      SizedBox(height: previewGap),
                      const _PreviewRow(label: '현금', value: '₩ 30,000,000'),
                      SizedBox(height: previewGap),
                      const _PreviewRow(label: '주식/ETF', value: '₩ 45,000,000'),
                      SizedBox(height: previewGap),
                      const _PreviewRow(label: '예금/적금', value: '₩ 15,000,000'),
                      SizedBox(height: previewGap),
                      const _PreviewRow(label: '부동산', value: '₩ 10,000,000'),
                      SizedBox(height: isCompactWide ? 14 : 18),
                      const Text(
                        '현재는 UI 기반 MVP 단계입니다.\n다음 단계에서 실제 데이터와 연결합니다.',
                        style: TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroTag extends StatelessWidget {
  final String text;

  const _HeroTag({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}