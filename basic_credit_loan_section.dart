import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 생활 신용대출: 서버의 가심사/실행/상환 RPC만 사용합니다.
/// 상위 팝업이 스크롤을 담당하므로 이 위젯에는 내부 스크롤이 없습니다.
class BasicCreditLoanSection extends StatefulWidget {
  final String productId;
  final VoidCallback? onChanged;

  const BasicCreditLoanSection({
    super.key,
    required this.productId,
    this.onChanged,
  });

  @override
  State<BasicCreditLoanSection> createState() => _BasicCreditLoanSectionState();
}

class _BasicCreditLoanSectionState extends State<BasicCreditLoanSection> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFE5E7EB);
  static const _soft = Color(0xFFF9FAFB);

  final _client = Supabase.instance.client;
  final _fmt = NumberFormat('#,##0');
  final _amountController = TextEditingController();

  int _term = 180;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic> _quote = {};
  List<Map<String, dynamic>> _loans = [];

  String? _issueRequestKey;
  String? _repaySignature;
  String? _repayRequestKey;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_resetIssueKey);
    _load();
  }

  @override
  void dispose() {
    _amountController.removeListener(_resetIssueKey);
    _amountController.dispose();
    super.dispose();
  }

  void _resetIssueKey() => _issueRequestKey = null;

  int _int(dynamic v) => v is num
      ? v.toInt()
      : int.tryParse(v?.toString() ?? '') ?? 0;

  String _won(dynamic v) => '${_fmt.format(_int(v))}원';

  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final text = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${text.substring(0, 8)}-${text.substring(8, 12)}-'
        '${text.substring(12, 16)}-${text.substring(16, 20)}-${text.substring(20)}';
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<dynamic>([
        _client.rpc('get_my_credit_loan_quote', params: {
          'p_product_id': widget.productId,
          'p_term_game_days': _term,
        }),
        _client.rpc('get_my_credit_loans'),
      ]);
      if (!mounted) return;
      setState(() {
        _quote = result[0] is Map
            ? Map<String, dynamic>.from(result[0] as Map)
            : {};
        _loans = result[1] is List
            ? (result[1] as List)
                .map((v) => Map<String, dynamic>.from(v as Map))
                .toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _status(String? status) {
    switch (status) {
      case 'eligible': return '신청 가능 · 실행 시 최종 재심사';
      case 'low_credit_score': return '게임 신용점수가 기준에 미달합니다.';
      case 'delinquent': return '연체 또는 부도 이력으로 신규 대출이 제한됩니다.';
      case 'existing_credit_loan': return '이용 중인 신용대출을 먼저 상환해주세요.';
      case 'credit_cooldown': return '최근 대출 실행 후 30게임일이 지나야 재신청할 수 있습니다.';
      case 'below_minimum': return '현재 승인한도가 최소 신청금액보다 낮습니다.';
      default: return '현재 대출 신청이 불가능합니다.';
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _ink),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _issue() async {
    if (_loading || _busy || _quote['status'] != 'eligible') return;
    final amount = int.tryParse(_amountController.text);
    final min = _int(_quote['min_amount']);
    final max = _int(_quote['approval_limit']);
    if (amount == null || amount < min || amount > max) {
      _notice('신청금액은 ${_won(min)} ~ ${_won(max)} 사이여야 합니다.');
      return;
    }
    final accepted = await _confirm('신용대출 실행',
        '대출금 ${_won(amount)}이 생활계좌에 입금되고 같은 금액이 부채로 기록됩니다.\n'
        '금리 연 ${_quote['annual_rate']}% / 기간 $_term게임일\n'
        '30게임일마다 원리금을 상환합니다. 진행하시겠습니까?');
    if (!accepted || !mounted) return;

    _issueRequestKey ??= _uuid();
    setState(() => _busy = true);
    try {
      final response = await _client.rpc('issue_basic_credit_loan', params: {
        'p_product_id': widget.productId,
        'p_amount': amount,
        'p_term_game_days': _term,
        'p_request_key': _issueRequestKey,
      });
      if (response is! Map || response['success'] != true) {
        throw Exception('대출 실행 결과를 확인하지 못했습니다.');
      }
      _issueRequestKey = null;
      _amountController.clear();
      await _load();
      widget.onChanged?.call();
      _notice('생활계좌에 ${_won(amount)} 대출금이 지급되었습니다.');
    } catch (e) {
      _notice('대출 실행 실패: $e');
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _repay(Map<String, dynamic> loan, String mode) async {
    if (_busy) return;
    int? partial;
    if (mode == 'partial_early') {
      final controller = TextEditingController();
      try {
        partial = await showDialog<int>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('일부상환 금액'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '상환금액 (원)',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                    dialogContext, int.tryParse(controller.text)),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } finally {
        // Dialog transition has ended when showDialog completes.
        controller.dispose();
      }
      if (partial == null || partial <= 0) return;
    }
    if (!mounted) return;
    final label = switch (mode) {
      'scheduled' => '정기상환',
      'partial_early' => '일부상환',
      _ => '전액상환',
    };
    final accepted = await _confirm(label,
        '생활계좌에서 상환금이 차감됩니다.\n'
        '전체 상환 필요액: ${_won(loan['total_repayment_amount'])}\n'
        '${partial != null ? '입력 상환액: ${_won(partial)}\n' : ''}'
        '최종 이자는 서버에서 재계산합니다. 진행하시겠습니까?');
    if (!accepted || !mounted) return;

    final signature = '${loan['id']}:$mode:${partial ?? 0}';
    if (_repaySignature != signature || _repayRequestKey == null) {
      _repaySignature = signature;
      _repayRequestKey = _uuid();
    }
    setState(() => _busy = true);
    try {
      final response = await _client.rpc('repay_basic_credit_loan', params: {
        'p_loan_id': loan['id'],
        'p_mode': mode,
        'p_request_key': _repayRequestKey,
        'p_amount': partial,
      });
      if (response is! Map || response['success'] != true) {
        throw Exception('상환 결과를 확인하지 못했습니다.');
      }
      _repaySignature = null;
      _repayRequestKey = null;
      await _load();
      widget.onChanged?.call();
      _notice('${_won(response['payment'])} 상환 완료');
    } catch (e) {
      _notice('상환 실패: $e');
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _lineItem(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label,
              style: const TextStyle(color: _muted, fontSize: 12))),
          Expanded(child: Text(text,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _loanCard(Map<String, dynamic> loan) {
    final day = _int(loan['game_day']);
    final due = _int(loan['next_payment_game_day']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(loan['product_name']?.toString() ?? '신용대출',
            style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 10),
        _lineItem('잔여 원금', _won(loan['outstanding_principal'])),
        _lineItem('발생 이자', _won(loan['interest_due'])),
        _lineItem('전체 상환액', _won(loan['total_repayment_amount'])),
        _lineItem('회차 상환액', _won(loan['scheduled_payment'])),
        _lineItem('다음 상환일', '게임 D+$due${day > due ? ' · 연체' : ''}'),
        Wrap(spacing: 8, runSpacing: 6, children: [
          OutlinedButton(
            onPressed: _busy || day < due ? null : () => _repay(loan, 'scheduled'),
            child: const Text('정기상환'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _repay(loan, 'partial_early'),
            child: const Text('일부상환'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _repay(loan, 'full_early'),
            child: const Text('전액상환'),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(28),
        child: CircularProgressIndicator(color: _ink),
      ));
    }
    if (_error != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_error!),
        TextButton(onPressed: _load, child: const Text('다시 조회')),
      ]);
    }
    final limit = _int(_quote['approval_limit']);
    final available = _quote['status'] == 'eligible';
    final min = _int(_quote['min_amount']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('생활 신용대출 신청·상환',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink)),
      const SizedBox(height: 12),
      if (_loans.isEmpty)
        const Text('이용 중인 신용대출이 없습니다.',
            style: TextStyle(color: _muted))
      else
        for (final loan in _loans) _loanCard(loan),
      const Divider(height: 30, color: _line),
      _lineItem('게임 신용점수', '${_quote['credit_score'] ?? '-'}점'),
      _lineItem('대출금리', '연 ${_quote['annual_rate'] ?? '-'}%'),
      _lineItem('예상 승인한도', _won(limit)),
      _lineItem('최소 신청금액', _won(min)),
      const SizedBox(height: 4),
      Text(
        _status(_quote['status']?.toString()),
        style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
      ),
      const SizedBox(height: 12),
      const Text('대출기간', style: TextStyle(fontWeight: FontWeight.w700)),
      Wrap(spacing: 8, children: [
        for (final days in const [30, 60, 90, 180])
          ChoiceChip(
            label: Text('${days ~/ 30}개월'),
            selected: _term == days,
            onSelected: _busy ? null : (selected) {
              if (!selected) return;
              _term = days;
              _issueRequestKey = null;
              _load();
            },
          ),
      ]),
      const SizedBox(height: 12),
      TextField(
        controller: _amountController,
        enabled: available && !_busy,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: '대출 신청금액 (원)',
          hintText: available ? '최대 ${_won(limit)}' : '현재 신청할 수 없습니다',
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: available && !_busy ? _issue : null,
        style: FilledButton.styleFrom(backgroundColor: _ink),
        child: Text(_busy ? '처리 중' : '대출 실행'),
      ),
      const SizedBox(height: 10),
      const Text('직업·급여는 필수가 아닙니다. 신용점수·기존 대출·연체 이력 및 '
          '검증 가능한 현금흐름을 바탕으로 최종 한도를 산정합니다. '
          '대출 실행 전 서버에서 조건을 다시 확인합니다.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.5)),
    ]);
  }
}
