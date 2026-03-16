import 'package:flutter/material.dart';

class BottomNoticeSection extends StatelessWidget {
  const BottomNoticeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Text(
            '현재 진행 상태',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Flutter Web 프로젝트 생성, GitHub 연결, Supabase 연결, 홈 화면 구성까지 완료되었습니다.\n다음 단계에서는 회원가입 후 사용자 자산 기본값 생성과 자산 카테고리별 테이블 구조를 연결합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 14,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}