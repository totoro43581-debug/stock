import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TopHeaderSection extends StatelessWidget {
  final Session? session;

  const TopHeaderSection({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock Web Game',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '경제 활동 모의 플랫폼',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const _HeaderMenuText(text: '홈'),
            const SizedBox(width: 28),
            const _HeaderMenuText(text: '자산현황'),
            const SizedBox(width: 28),
            const _HeaderMenuText(text: '주식'),
            const SizedBox(width: 28),
            const _HeaderMenuText(text: 'ETF'),
            const SizedBox(width: 28),
            const _HeaderMenuText(text: '예금/적금'),
            const SizedBox(width: 28),
            const _HeaderMenuText(text: '부동산'),
            const SizedBox(width: 28),
            const _HeaderMenuText(text: '리포트'),
            const SizedBox(width: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: session == null
                    ? const Color(0xFFF3F4F6)
                    : const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                session == null ? '비로그인' : '로그인됨',
                style: TextStyle(
                  color: session == null
                      ? const Color(0xFF4B5563)
                      : const Color(0xFF1D4ED8),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderMenuText extends StatelessWidget {
  final String text;

  const _HeaderMenuText({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF374151),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}