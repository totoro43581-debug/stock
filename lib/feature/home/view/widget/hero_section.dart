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
        final double width = constraints.maxWidth;

        final bool isDesktop = width >= 760;
        final bool isMobile = width < 520;

        final double outerPadding = isMobile
            ? 20
            : isDesktop
            ? 32
            : 24;

        final double titleFontSize = isMobile
            ? 30
            : isDesktop
            ? 42
            : 36;

        final double bodyFontSize = isMobile ? 14 : 16;
        final double sectionGap = isMobile ? 16 : 22;

        final Widget leftContent = _HeroMainContent(
          titleFontSize: titleFontSize,
          bodyFontSize: bodyFontSize,
          sectionGap: sectionGap,
          isMobile: isMobile,
        );

        final Widget previewContent = _HeroPreviewCard(
          isMobile: isMobile,
        );

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
          child: isDesktop
              ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: leftContent,
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: previewContent,
              ),
            ],
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              leftContent,
              SizedBox(height: sectionGap),
              previewContent,
            ],
          ),
        );
      },
    );
  }
}

class _HeroMainContent extends StatelessWidget {
  const _HeroMainContent({
    required this.titleFontSize,
    required this.bodyFontSize,
    required this.sectionGap,
    required this.isMobile,
  });

  final double titleFontSize;
  final double bodyFontSize;
  final double sectionGap;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 520),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: sectionGap),
        Text(
          '주식만이 아니라\n예금, 코인, 부동산까지',
          style: TextStyle(
            color: Colors.white,
            fontSize: titleFontSize,
            height: 1.18,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        Text(
          '가상의 자산으로 다양한 경제 활동을 체험하고,\n자산 배분과 수익률 변화를 직접 비교해볼 수 있습니다.',
          maxLines: isMobile ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFFD1D5DB),
            fontSize: bodyFontSize,
            height: 1.6,
          ),
        ),
        SizedBox(height: sectionGap),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _HeroTag(text: '예/적금'),
            _HeroTag(text: '주식'),
            _HeroTag(text: '코인'),
            _HeroTag(text: '부동산'),
            _HeroTag(text: '리포트'),
            _HeroTag(text: '자유게시판'),
          ],
        ),
      ],
    );
  }
}

class _HeroPreviewCard extends StatelessWidget {
  const _HeroPreviewCard({
    required this.isMobile,
  });

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
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
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const _PreviewRow(label: '총 자산', value: '₩ 100,000,000'),
          const SizedBox(height: 10),
          const _PreviewRow(label: '현금', value: '₩ 30,000,000'),
          const SizedBox(height: 10),
          const _PreviewRow(label: '주식', value: '₩ 45,000,000'),
          const SizedBox(height: 10),
          const _PreviewRow(label: '예/적금', value: '₩ 15,000,000'),
          const SizedBox(height: 10),
          const _PreviewRow(label: '부동산', value: '₩ 10,000,000'),
          const SizedBox(height: 16),
          const Text(
            '현재는 UI 기반 MVP 단계입니다.\n다음 단계에서 실제 데이터와 연결합니다.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}