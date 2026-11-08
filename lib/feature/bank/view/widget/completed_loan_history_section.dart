import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock/core/game_time/game_time_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ink = Color(0xFF111827);
const _muted = Color(0xFF4B5563);
const _line = Color(0xFFE5E7EB);

String _amount(dynamic value) {
  final amount = num.tryParse(value?.toString() ?? '');
  return amount == null || !amount.isFinite
      ? '내역 확인 불가'
      : '${NumberFormat('#,##0.##').format(amount)}원';
}

String _paymentTime(dynamic value) {
  final time = DateTime.tryParse(value?.toString() ?? '');
  return time == null
      ? '상환 시각 확인 불가'
      : realDeadlineLabel(time, showRemaining: false);
}

Widget _metric(String label, String value, {bool prominent = false}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      label,
      style: const TextStyle(fontSize: 14, color: _muted, height: 1.5),
    ),
    const SizedBox(height: 4),
    Text(
      value,
      style: TextStyle(
        fontSize: prominent ? 22 : 16,
        fontWeight: FontWeight.w700,
        color: _ink,
        height: 1.5,
      ),
    ),
  ],
);

Widget _metrics(List<Widget> items) => LayoutBuilder(
  builder: (context, constraints) {
    final count = constraints.maxWidth >= 780
        ? 4
        : constraints.maxWidth >= 440
        ? 2
        : 1;
    final width = (constraints.maxWidth - (count - 1) * 20) / count;
    return Wrap(
      spacing: 20,
      runSpacing: 16,
      children: [for (final item in items) SizedBox(width: width, child: item)],
    );
  },
);

class _HistoryPage {
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? cursor;
  const _HistoryPage(this.items, this.cursor);

  factory _HistoryPage.parse(dynamic response, String timestampField) {
    if (response is! Map ||
        response['items'] is! List ||
        response['has_more'] is! bool) {
      throw const FormatException('상환 내역 응답을 확인할 수 없습니다.');
    }
    final items = (response['items'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    if (items.any((item) => item['id'] is! String)) {
      throw const FormatException('상환 내역 식별자가 없습니다.');
    }
    Map<String, dynamic>? cursor;
    if (response['has_more'] == true) {
      if (response['next_cursor'] is! Map || items.isEmpty) {
        throw const FormatException('다음 조회 기준을 확인할 수 없습니다.');
      }
      cursor = Map<String, dynamic>.from(response['next_cursor'] as Map);
      if (cursor['id'] is! String ||
          DateTime.tryParse(cursor[timestampField]?.toString() ?? '') == null) {
        throw const FormatException('다음 조회 기준이 올바르지 않습니다.');
      }
    }
    return _HistoryPage(items, cursor);
  }
}

/// Archived contracts only. This widget never calls a disbursement or payment RPC.
class CompletedLoanHistorySection extends StatefulWidget {
  const CompletedLoanHistorySection({super.key});

  @override
  State<CompletedLoanHistorySection> createState() =>
      _CompletedLoanHistorySectionState();
}

class _CompletedLoanHistorySectionState
    extends State<CompletedLoanHistorySection> {
  final _client = Supabase.instance.client;
  final _loans = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _retryAppend = false;
  String? _error;
  Map<String, dynamic>? _cursor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (append && (_loading || _cursor == null)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _client.rpc(
        'get_my_repaid_loans',
        params: {
          'p_limit': 20,
          'p_before_updated_at': append ? (_cursor?['updated_at']) : null,
          'p_before_id': append ? (_cursor?['id']) : null,
        },
      );
      final page = _HistoryPage.parse(response, 'updated_at');
      if (!mounted) return;
      setState(() {
        if (!append) _loans.clear();
        final ids = _loans.map((item) => item['id']).toSet();
        _loans.addAll(page.items.where((item) => ids.add(item['id'])));
        _cursor = page.cursor;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '상환 완료 내역을 불러오지 못했습니다. 다시 조회해 주세요.';
        _retryAppend = append;
        _loading = false;
      });
    }
  }

  Widget _card(Map<String, dynamic> loan) {
    final name = loan['product_name']?.toString() ?? '대출';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '상환 완료',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            loan['loan_type'] == 'credit'
                ? '신용대출'
                : loan['loan_type'] == 'deposit_secured'
                ? '예금담보대출'
                : '대출',
            style: const TextStyle(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 18),
          _metric('누적 상환액', _amount(loan['total_paid']), prominent: true),
          const SizedBox(height: 18),
          _metrics([
            _metric('최초 대출원금', _amount(loan['principal_amount'])),
            _metric('상환한 원금', _amount(loan['principal_paid'])),
            _metric('상환한 이자', _amount(loan['interest_paid'])),
            _metric('상환 수수료', _amount(loan['fee_paid'])),
          ]),
          const SizedBox(height: 18),
          _metric('최종 상환 · 한국시간', _paymentTime(loan['last_payment_at'])),
          const SizedBox(height: 18),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (loan['payment_count'] is num)
                Text(
                  '상환 기록 ${loan['payment_count']}건',
                  style: const TextStyle(fontSize: 14, color: _muted),
                ),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _PaymentHistoryDialog(
                    loanId: loan['id'] as String,
                    productName: name,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(130, 48),
                  foregroundColor: _ink,
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 20),
                label: const Text(
                  '상환 기록',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        '상환을 마친 대출과 실제 납부한 원금·이자·수수료를 확인할 수 있습니다.',
        style: TextStyle(fontSize: 14, color: _muted, height: 1.5),
      ),
      const SizedBox(height: 16),
      if (_loading && _loans.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_error == null && _loans.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '상환 완료된 대출이 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _muted),
          ),
        )
      else
        for (final loan in _loans)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _card(loan),
          ),
      if (_error != null) ...[
        Text(
          _error!,
          style: const TextStyle(fontSize: 14, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _loading ? null : () => _load(append: _retryAppend),
            child: const Text('상환 완료 내역 다시 조회', style: TextStyle(fontSize: 14)),
          ),
        ),
      ] else if (_cursor != null)
        OutlinedButton(
          onPressed: _loading ? null : () => _load(append: true),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _loading ? '불러오는 중...' : '상환 완료 내역 더 보기',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
    ],
  );
}

class _PaymentHistoryDialog extends StatefulWidget {
  final String loanId;
  final String productName;
  const _PaymentHistoryDialog({
    required this.loanId,
    required this.productName,
  });
  @override
  State<_PaymentHistoryDialog> createState() => _PaymentHistoryDialogState();
}

class _PaymentHistoryDialogState extends State<_PaymentHistoryDialog> {
  final _payments = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _retryAppend = false;
  String? _error;
  Map<String, dynamic>? _cursor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (append && (_loading || _cursor == null)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.rpc(
        'get_my_loan_payment_history',
        params: {
          'p_loan_id': widget.loanId,
          'p_limit': 20,
          'p_before_created_at': append ? (_cursor?['created_at']) : null,
          'p_before_id': append ? (_cursor?['id']) : null,
        },
      );
      final page = _HistoryPage.parse(response, 'created_at');
      if (!mounted) return;
      setState(() {
        if (!append) _payments.clear();
        final ids = _payments.map((item) => item['id']).toSet();
        _payments.addAll(page.items.where((item) => ids.add(item['id'])));
        _cursor = page.cursor;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '상환 기록을 불러오지 못했습니다. 다시 조회해 주세요.';
        _retryAppend = append;
        _loading = false;
      });
    }
  }

  Widget _receipt(Map<String, dynamic> item) {
    final type = switch (item['payment_type']) {
      'scheduled' => '정기상환',
      'partial_early' => '일부상환',
      'full_early' => '전액상환',
      'overdue' => '연체 상환',
      _ => '상환',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '납부 시각 · 한국시간',
            style: TextStyle(fontSize: 14, color: _muted, height: 1.5),
          ),
          const SizedBox(height: 4),
          Text(
            _paymentTime(item['created_at']),
            style: const TextStyle(fontSize: 14, color: _muted, height: 1.5),
          ),
          const SizedBox(height: 14),
          _metric('납부액', _amount(item['total_paid']), prominent: true),
          const SizedBox(height: 14),
          _metrics([
            _metric('원금', _amount(item['principal_paid'])),
            _metric('이자', _amount(item['interest_paid'])),
            _metric('수수료', _amount(item['fee_paid'])),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: SizedBox(
      width: 720,
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '상환 기록',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.productName,
                        style: const TextStyle(fontSize: 14, color: _muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: '닫기',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading && _payments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error == null && _payments.isEmpty)
                    const Text(
                      '표시할 상환 기록이 없습니다.',
                      style: TextStyle(fontSize: 15, color: _muted),
                    )
                  else
                    for (final item in _payments) _receipt(item),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _muted,
                        height: 1.5,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => _load(append: _retryAppend),
                      child: const Text(
                        '상환 기록 다시 조회',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ] else if (_cursor != null)
                    OutlinedButton(
                      onPressed: _loading ? null : () => _load(append: true),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _loading ? '불러오는 중...' : '상환 기록 더 보기',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
