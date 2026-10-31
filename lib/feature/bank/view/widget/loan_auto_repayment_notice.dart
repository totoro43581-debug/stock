import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock/core/game_time/game_time_service.dart';

class LoanAutoRepaymentNotice extends StatelessWidget {
  final Map<String, dynamic> loan;
  final bool isCredit;

  const LoanAutoRepaymentNotice({
    super.key,
    required this.loan,
    required this.isCredit,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = loan['automatic_repayment_enabled'] == true;
    final result = loan['automatic_repayment_result']?.toString();
    final needsAttention = enabled && result != null && result != 'paid';
    final color = needsAttention
        ? const Color(0xFF92400E)
        : const Color(0xFF1D4ED8);
    final payment = num.tryParse(loan['scheduled_payment']?.toString() ?? '');
    final attempt = DateTime.tryParse(
      loan['automatic_repayment_attempted_at']?.toString() ?? '',
    );
    final status = switch (result) {
      'paid' => '최근 자동상환 완료',
      'insufficient_funds' => '자동상환 대기 · 생활계좌 잔액 부족',
      'no_bank_account' => '자동상환 대기 · 생활계좌 확인 필요',
      'error' => '자동상환 처리 확인 필요 · 새로고침 후 확인해 주세요.',
      _ => null,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            enabled ? '기본 자동상환' : '자동상환 적용 대기',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            !enabled
                ? '서버 적용 전입니다. 현재 자동으로 출금되지 않으며 직접 상환할 수 있습니다.'
                : isCredit
                ? '${payment != null && payment > 0 ? '약정 회차 상환액 ${NumberFormat('#,##0').format(payment)}원. ' : ''}정기상환일에 생활계좌에서 상환하며, 만기에는 남은 원금과 이자를 상환합니다.'
                : '만기에 생활계좌에서 남은 원금과 이자를 전액상환합니다.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF374151),
            ),
          ),
          if (enabled) ...[
            const SizedBox(height: 6),
            const Text(
              '서버가 현실 1분 간격으로 확인합니다. 잔액 부족 시 다음 확인 때 다시 시도합니다.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF4B5563),
              ),
            ),
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(
                status,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
            if (attempt != null)
              Text(
                '최근 확인: ${realDeadlineLabel(attempt, showRemaining: false)} (한국시간)',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF4B5563),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
