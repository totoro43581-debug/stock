import 'package:flutter/material.dart';

class FeatureSection extends StatelessWidget {
  const FeatureSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '서비스 방향',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 16),
          Text(
            '이 서비스는 단순한 퀘스트형 투자 게임이 아니라, 사용자가 가상의 자산을 가지고 여러 경제 활동을 수행하며 자산 운용 감각을 익히는 모의 플랫폼을 목표로 합니다.',
            style: TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 15,
              height: 1.8,
            ),
          ),
          SizedBox(height: 20),
          _FeatureBullet(text: '총 자산, 현금, 금융자산, 부동산 자산을 통합 관리'),
          SizedBox(height: 10),
          _FeatureBullet(text: '주식, ETF, 예금, 적금, 부동산을 각각 별도 기능으로 구성'),
          SizedBox(height: 10),
          _FeatureBullet(text: '월별/기간별 자산 변화와 수익률 비교 리포트 제공'),
          SizedBox(height: 10),
          _FeatureBullet(text: '향후 랭킹 또는 사용자 간 비교 기능 확장 가능'),
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final String text;

  const _FeatureBullet({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 15,
              height: 1.7,
            ),
          ),
        ),
      ],
    );
  }
}