
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameEmploymentSection extends StatefulWidget {
  final VoidCallback? onChanged;

  const GameEmploymentSection({
    super.key,
    this.onChanged,
  });

  @override
  State<GameEmploymentSection> createState() =>
      _GameEmploymentSectionState();
}

class _GameEmploymentSectionState
    extends State<GameEmploymentSection> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFE5E7EB);
  static const _soft = Color(0xFFF9FAFB);

  final _client = Supabase.instance.client;
  final _money = NumberFormat('#,##0');

  bool _loading = true;
  bool _working = false;
  String? _error;

  Map<String, dynamic> _data = {};

  Map<String, dynamic>? get _employment {
    final value = _data['employment'];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Map<String, dynamic> get _income {
    final value = _data['income'];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  List<Map<String, dynamic>> get _jobs {
    final value = _data['jobs'];
    if (value is! List) return [];

    return value
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _won(dynamic value) {
    return '${_money.format(_int(value))}원';
  }

  String _period(int days) {
    if (days == 1) return '매 게임 1일';
    if (days == 7) return '게임 1주일';
    if (days == 30) return '게임 1개월';
    return '게임 $days일';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text)),
      );
  }

  Future<void> _load({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response =
      await _client.rpc('get_my_game_employment');

      if (!mounted) return;

      setState(() {
        _data = response is Map
            ? Map<String, dynamic>.from(response)
            : {};
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _startJob(Map<String, dynamic> job) async {
    if (_working) return;

    final current = _employment;
    final name = job['job_name']?.toString() ?? '';
    final cycle = _int(job['pay_cycle_game_days']);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          current == null ? '직업 선택' : '직업 변경',
        ),
        content: Text(
          '$name\n'
              '급여: ${_won(job['pay_amount'])}\n'
              '지급주기: ${_period(cycle)}\n\n'
              '직업을 선택하면 새로운 급여주기가 시작됩니다.'
              '\n직업 변경 시 기존의 미완료 근무기간은 승계되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: Colors.white,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _working = true);

    try {
      await _client.rpc(
        'start_game_job',
        params: {
          'p_job_code': job['job_code'],
        },
      );

      await _load(showLoading: false);

      if (!mounted) return;

      widget.onChanged?.call();
      _message('$name 직업이 등록되었습니다.');
    } catch (e) {
      _message('직업 선택 실패: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _claimSalary() async {
    if (_working) return;

    setState(() => _working = true);

    try {
      final result = await _client.rpc('claim_game_salary');

      await _load(showLoading: false);

      if (!mounted) return;

      widget.onChanged?.call();

      final amount = result is Map ? result['amount'] : 0;

      _message(
        '급여 ${_won(amount)}이 생활계좌에 입금되었습니다.',
      );
    } catch (e) {
      _message('급여 수령 실패: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Widget _jobCard(Map<String, dynamic> job) {
    final current = _employment;
    final selected =
        current?['job_code'] == job['job_code'];

    final canChange =
        current == null || current['can_switch'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? _ink : _line,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job['job_name']?.toString() ?? '',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _won(job['pay_amount']),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _period(_int(job['pay_cycle_game_days'])),
            style: const TextStyle(
              fontSize: 12,
              color: _muted,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: selected || !canChange || _working
                  ? null
                  : () => _startJob(job),
              child: Text(
                selected
                    ? '현재 직업'
                    : canChange
                    ? '선택하기'
                    : '변경 대기',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: _ink),
        ),
      );
    }

    if (_error != null) {
      return Column(
        children: [
          Text(_error!),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _load,
            child: const Text('다시 조회'),
          ),
        ],
      );
    }

    final employment = _employment;
    final canClaim = employment?['can_claim'] == true;
    final remaining =
    _int(employment?['remaining_game_days']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '직업·급여 관리',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ),
            IconButton(
              onPressed: _working
                  ? null
                  : () => _load(showLoading: false),
              tooltip: '새로고침',
              icon: const Icon(Icons.refresh, color: _ink),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '현재 게임 D+${_int(_data['game_day'])} · '
              '게임 시간에 따라 급여 지급일이 결정됩니다.',
          style: const TextStyle(
            fontSize: 12,
            color: _muted,
          ),
        ),
        const SizedBox(height: 16),

        if (employment == null)
          const Text(
            '현재 직업이 없습니다. 아래에서 직업을 선택하세요.',
            style: TextStyle(color: _muted),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employment['job_name']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '급여 ${_won(employment['pay_amount'])} '
                      '· ${_period(_int(employment['pay_cycle_game_days']))}',
                ),
                const SizedBox(height: 5),
                Text(
                  canClaim
                      ? '급여 수령 가능'
                      : '급여 수령까지 게임 $remaining일',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: canClaim && !_working
                      ? _claimSalary
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _working
                        ? '처리 중'
                        : canClaim
                        ? '급여 수령'
                        : '지급일 대기',
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 18),
        const Text(
          '직업 선택',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 10),

        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 590 ? 3 : 1;
            final itemWidth =
                (width - 10 * (columns - 1)) / columns;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final job in _jobs)
                  SizedBox(
                    width: itemWidth,
                    child: _jobCard(job),
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 18),
        const Divider(color: _line),
        const SizedBox(height: 8),

        const Text(
          '대출 심사용 소득',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),

        Text(
          _income['income_verified'] == true
              ? '검증 연 소득: ${_won(_income['annual_income'])}'
              : '소득 검증 진행 중 · '
              '급여 수령 기록 ${_int(_income['verified_income_records'])}건',
          style: const TextStyle(
            fontSize: 13,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),

        const Text(
          '신용대출 심사에는 서로 다른 지급기간에서 발생한 '
              '30게임일 이상의 검증된 소득 기록이 필요합니다. '
              '직업 변경은 게임 7일 후 가능하며, '
              '미완료 급여주기는 이월되지 않습니다.',
          style: TextStyle(
            fontSize: 12,
            color: _muted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
