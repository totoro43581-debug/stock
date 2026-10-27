import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/bank/view/widget/deposit_secured_loan_section.dart';

class LoanCatalogSection extends StatefulWidget {
  final VoidCallback? onChanged;

  const LoanCatalogSection({super.key, this.onChanged});

  @override
  State<LoanCatalogSection> createState() => _LoanCatalogSectionState();
}

class _LoanCatalogSectionState extends State<LoanCatalogSection> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFE5E7EB);
  static const _soft = Color(0xFFF9FAFB);

  final _money = NumberFormat('#,##0');

  bool _loading = true;
  String? _error;
  String _category = 'all';

  List<Map<String, dynamic>> _offers = [];
  Map<String, dynamic> _overview = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _won(dynamic value) {
    return '${_money.format(_number(value).round())}원';
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;

      final result = await Future.wait<dynamic>([
        client.rpc('get_my_loan_offers'),
        client.rpc('get_my_loan_overview'),
      ]);

      if (!mounted) return;

      setState(() {
        _offers = result[0] is List
            ? (result[0] as List)
                  .map((value) => Map<String, dynamic>.from(value as Map))
                  .toList()
            : [];

        _overview = result[1] is Map
            ? Map<String, dynamic>.from(result[1] as Map)
            : {};

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _loanType(String type) {
    switch (type) {
      case 'credit':
        return '신용대출';
      case 'overdraft':
        return '마이너스통장';
      case 'deposit_secured':
        return '예금담보대출';
      case 'home_purchase':
        return '주택구입자금대출';
      case 'home_equity':
        return '주택담보대출';
      case 'land_secured':
        return '토지담보대출';
      case 'commercial_secured':
        return '상가담보대출';
      case 'building_secured':
        return '건물담보대출';
      case 'business':
        return '사업자대출';
      default:
        return type;
    }
  }

  String _repayment(String method) {
    switch (method) {
      case 'amortized':
        return '원리금균등';
      case 'equal_principal':
        return '원금균등';
      case 'bullet':
        return '만기일시';
      case 'interest_only':
        return '이자 납부 후 원금상환';
      case 'revolving':
        return '한도대출';
      default:
        return method;
    }
  }

  String _earlyRepayment(Map<String, dynamic> offer) {
    final policy = offer['early_repayment_policy']?.toString();

    switch (policy) {
      case 'free':
        return '자유 중도상환 · 수수료 없음';

      case 'fee':
        final rate = _number(offer['early_repayment_fee_rate']) * 100;

        final days = _number(offer['fee_period_game_days']).toInt();

        return '중도상환 수수료 '
            '${rate.toStringAsFixed(2)}% · '
            '적용기간 게임 $days일';

      case 'partial_limited':
        final ratio = _number(offer['partial_repayment_limit_ratio']) * 100;

        return '일부상환 한도 '
            '${ratio.toStringAsFixed(0)}%';

      case 'lock_period':
        return '초기 게임 '
            '${_number(offer['lock_period_game_days']).toInt()}일 '
            '조기상환 제한';

      default:
        return '중도상환 조건 확인 필요';
    }
  }

  String _precheckMessage(String? status) {
    switch (status) {
      case 'precheck_possible':
        return '기본 가심사 조건 충족 · 최종 승인 아님';

      case 'income_not_verified':
        return '게임 소득정보 검증 필요';

      case 'credit_not_set':
        return '게임 신용점수 산정 필요';

      case 'low_credit_score':
        return '상품 신용점수 기준 미달';

      case 'insufficient_collateral':
        return '해당 은행의 담보 가능 예금이 부족합니다.';

      case 'limit_below_minimum':
        return '예상한도가 최소 대출금액보다 낮습니다.';

      case 'existing_credit_loan':
        return '이용 중인 신용대출이 있습니다.';

      case 'credit_cooldown':
        return '신용대출 재신청 제한기간입니다.';

      case 'delinquent':
        return '연체·부도 이력으로 신규 대출 제한';

      case 'property_not_connected':
        return '부동산 담보 시스템 연동 전';

      case 'business_not_connected':
        return '사업자·사업소득 시스템 연동 전';

      default:
        return '심사정보 확인 필요';
    }
  }

  bool _matchesCategory(Map<String, dynamic> offer) {
    final type = offer['loan_type']?.toString() ?? '';

    switch (_category) {
      case 'credit':
        return type == 'credit' || type == 'overdraft';

      case 'deposit':
        return type == 'deposit_secured';

      case 'property':
        return const {
          'home_purchase',
          'home_equity',
          'land_secured',
          'commercial_secured',
          'building_secured',
        }.contains(type);

      case 'business':
        return type == 'business';

      default:
        return true;
    }
  }

  bool _supported(Map<String, dynamic> offer) {
    final code = offer['product_code']?.toString();

    return offer['is_active'] == true &&
        (code == 'LOAN_DEPOSIT_SECURED' || code == 'LOAN_CREDIT_BASIC');
  }

  bool _precheckPossible(Map<String, dynamic> offer) {
    return _supported(offer) &&
        offer['precheck_status'] == 'precheck_possible' &&
        _number(offer['indicative_limit']) >= _number(offer['min_amount']);
  }

  String _cardStatus(Map<String, dynamic> offer) {
    if (!_supported(offer)) {
      return '준비 중';
    }

    if (_precheckPossible(offer)) {
      return '가심사 가능';
    }

    switch (offer['precheck_status']?.toString()) {
      case 'insufficient_collateral':
        return '담보예금 필요';

      case 'existing_credit_loan':
        return '대출 이용 중';

      case 'credit_cooldown':
        return '재신청 대기';

      case 'delinquent':
        return '연체 확인 필요';

      case 'low_credit_score':
        return '신용점수 미달';

      case 'income_not_verified':
        return '소득 확인 필요';

      default:
        return '조건 확인';
    }
  }

  String _compactMoney(dynamic value) {
    final amount = _number(value).floor();

    if (amount >= 100000000) {
      final eok = amount ~/ 100000000;
      final man = (amount % 100000000) ~/ 10000;

      return man == 0
          ? '${_money.format(eok)}억원'
          : '${_money.format(eok)}억 '
                '${_money.format(man)}만원';
    }

    if (amount >= 10000) {
      return '${_money.format(amount ~/ 10000)}만원';
    }

    return _won(amount);
  }

  String _compactTerm(int days) {
    if (days <= 0) return '-';
    if (days == 7) return '1주일';

    if (days % 365 == 0) {
      return '${days ~/ 365}년';
    }

    if (days < 365 && days % 30 == 0) {
      return '${days ~/ 30}개월';
    }

    return '$days일';
  }

  Widget _surface(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: child,
    );
  }

  Widget _summaryCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileSection() {
    final score = _overview['credit_score'];
    final income = _overview['annual_income'];
    final verified = _overview['income_verified'] == true;

    return _surface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '내 대출·심사 현황',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: '새로고침',
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 950
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;

              final width = (constraints.maxWidth - (count - 1) * 12) / count;

              final cards = <Widget>[
                _summaryCard(
                  '현재 대출원금 잔액',
                  _won(_overview['outstanding_principal']),
                ),
                _summaryCard(
                  '이용 중인 대출',
                  '${_number(_overview['active_loan_count']).toInt()}건',
                ),
                _summaryCard(
                  '게임 신용점수',
                  score == null
                      ? '미산정'
                      : '$score점 (${_overview['credit_grade'] ?? '일반'})',
                ),
                _summaryCard(
                  '검증된 게임 연 소득',
                  verified && income != null ? _won(income) : '없음',
                ),
              ];

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final card in cards) SizedBox(width: width, child: card),
                ],
              );
            },
          ),
          const Text(
            '대출 심사 시점과 실제 대출 실행 시점의 '
            '조건은 달라질 수 있습니다.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$label  $value',
        style: const TextStyle(fontSize: 12, color: _ink, height: 1.4),
      ),
    );
  }

  Future<void> _showLoanDetails(Map<String, dynamic> offer) async {
    if (!mounted) return;

    final isDeposit = offer['product_code'] == 'LOAN_DEPOSIT_SECURED';

    final canOpen = _supported(offer);

    bool showingApplication = false;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 680,
            height: MediaQuery.sizeOf(dialogContext).height * 0.82,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          showingApplication
                              ? (isDeposit ? '예금담보대출 신청·상환' : '생활 신용대출 신청·상환')
                              : '대출상품 상세',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
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
                    child: showingApplication
                        ? (isDeposit
                              ? DepositSecuredLoanSection(
                                  onChanged: () {
                                    Navigator.of(dialogContext).pop();

                                    if (mounted) {
                                      _load();
                                      widget.onChanged?.call();
                                    }
                                  },
                                )
                              : _BasicCreditLoanSection(
                                  productId: offer['id'].toString(),
                                  onChanged: () {
                                    if (mounted) {
                                      _load();
                                      widget.onChanged?.call();
                                    }
                                  },
                                ))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offer['bank_name']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                offer['product_name']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _loanType(offer['loan_type']?.toString() ?? ''),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '연 ${_number(offer['annual_rate']).toStringAsFixed(2)}%',
                                style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Divider(height: 30),
                              _detail('상품 최대한도', _won(offer['max_amount'])),
                              _detail('최소 신청금액', _won(offer['min_amount'])),
                              _detail(
                                '대출기간',
                                '게임 '
                                    '${_compactTerm(_number(offer['min_term_game_days']).toInt())}'
                                    ' ~ '
                                    '${_compactTerm(_number(offer['max_term_game_days']).toInt())}',
                              ),
                              _detail(
                                '상환방식',
                                _repayment(
                                  offer['repayment_method']?.toString() ?? '',
                                ),
                              ),
                              if (offer['min_credit_score'] != null)
                                _detail(
                                  '최소 신용점수',
                                  '${offer['min_credit_score']}점',
                                ),
                              if (offer['max_ltv'] != null)
                                _detail(
                                  '담보인정비율 상한',
                                  '${(_number(offer['max_ltv']) * 100).toStringAsFixed(0)}%',
                                ),
                              const Divider(height: 28),
                              const Text(
                                '중도상환 조건',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _earlyRepayment(offer),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                ),
                              ),
                              const Divider(height: 28),
                              const Text(
                                '개인 가심사',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                offer['indicative_limit'] == null
                                    ? '예상한도: 미산정'
                                    : '예상한도: '
                                          '${_won(offer['indicative_limit'])}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _precheckMessage(
                                  offer['precheck_status']?.toString(),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                if (!showingApplication) ...[
                  const Divider(height: 1, color: _line),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('닫기'),
                        ),
                        const Spacer(),
                        if (canOpen)
                          FilledButton(
                            onPressed: () {
                              updateDialog(() {
                                showingApplication = true;
                              });
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _ink,
                            ),
                            child: Text(
                              _precheckPossible(offer)
                                  ? '대출 신청·상환'
                                  : '조건 확인·상환',
                            ),
                          )
                        else
                          const OutlinedButton(
                            onPressed: null,
                            child: Text('출시 준비 중'),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _offerCard(Map<String, dynamic> offer) {
    final name = offer['product_name']?.toString() ?? '';

    final bank = offer['bank_name']?.toString() ?? '';

    final rate = _number(offer['annual_rate']);

    final minTerm = _number(offer['min_term_game_days']).toInt();

    final maxTerm = _number(offer['max_term_game_days']).toInt();

    final available = _precheckPossible(offer);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showLoanDetails(offer),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bank,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 17, color: _muted),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${rate.toStringAsFixed(2)}%',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: _line),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '최대한도',
                          style: TextStyle(fontSize: 10, color: _muted),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _compactMoney(offer['max_amount']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '대출기간',
                          style: TextStyle(fontSize: 10, color: _muted),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_compactTerm(minTerm)}'
                          '~${_compactTerm(maxTerm)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _repayment(offer['repayment_method']?.toString() ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _cardStatus(offer),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: available ? _ink : _muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productsSection() {
    const categories = [
      ('all', '전체'),
      ('credit', '신용·한도'),
      ('deposit', '예금담보'),
      ('property', '부동산담보'),
      ('business', '사업자'),
    ];

    final visible = _offers.where(_matchesCategory).toList();

    return _surface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '대출 상품',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '전체 ${_offers.length}개 상품 · '
            '가심사 결과는 최종 승인이 아닙니다.',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (id, label) in categories)
                ChoiceChip(
                  label: Text(label),
                  selected: _category == id,
                  onSelected: (_) {
                    setState(() {
                      _category = id;
                    });
                  },
                  selectedColor: _ink,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _line),
                  labelStyle: TextStyle(
                    color: _category == id ? Colors.white : _ink,
                  ),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              final count = width >= 1100
                  ? 5
                  : width >= 850
                  ? 4
                  : width >= 620
                  ? 3
                  : width >= 400
                  ? 2
                  : 1;

              final cardWidth = (width - (count - 1) * 10) / count;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final offer in visible)
                    SizedBox(width: cardWidth, child: _offerCard(offer)),
                ],
              );
            },
          ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('표시할 대출상품이 없습니다.', style: TextStyle(color: _muted)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator(color: _ink)),
      );
    }

    if (_error != null) {
      return _surface(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '대출정보 조회 오류',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: _muted)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('다시 조회')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _profileSection(),
        const SizedBox(height: 14),
        _productsSection(),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '※ 예금담보대출과 생활 신용대출은 신청·상환 '
            '화면을 제공합니다. 그 외 대출은 준비 중이며 '
            '최종 승인 여부는 실행 시 재심사합니다.',
            style: TextStyle(fontSize: 12, color: _muted, height: 1.5),
          ),
        ),
      ],
    );
  }
}

// 생활 신용대출 화면
// 별도 Dart 파일 없이 이 파일 내부에 포함

class _BasicCreditLoanSection extends StatefulWidget {
  final String productId;
  final VoidCallback? onChanged;

  const _BasicCreditLoanSection({required this.productId, this.onChanged});

  @override
  State<_BasicCreditLoanSection> createState() =>
      _BasicCreditLoanSectionState();
}

class _BasicCreditLoanSectionState extends State<_BasicCreditLoanSection> {
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFE5E7EB);
  static const _soft = Color(0xFFF9FAFB);

  final _client = Supabase.instance.client;
  final _money = NumberFormat('#,##0');
  final _amountController = TextEditingController();

  int _term = 180;

  bool _loading = true;
  bool _busy = false;

  String? _error;

  Map<String, dynamic> _quote = {};
  List<Map<String, dynamic>> _loans = [];
  DateTime? _gameEpoch;

  String? _issueKey;
  String? _repaySignature;
  String? _repayKey;

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

  void _resetIssueKey() {
    _issueKey = null;
  }

  int _integer(dynamic value) {
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _won(dynamic value) {
    return '${_money.format(_integer(value))}원';
  }

  String _uuid() {
    final random = Random.secure();

    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final value = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<DateTime?> _loadGameEpoch() async {
    try {
      final settings = await _client
          .from('game_clock_settings')
          .select('virtual_epoch')
          .eq('singleton_id', true)
          .single();

      return DateTime.tryParse(
        settings['virtual_epoch']?.toString() ?? '',
      )?.toUtc();
    } catch (_) {
      // A date lookup failure must not block loan applications or repayments.
      return null;
    }
  }

  String _gameDate(int gameDay) {
    final epoch = _gameEpoch;
    if (epoch == null) return '날짜 확인 불가';

    // get_game_clock defines game_day as whole days since virtual_epoch (day 0).
    final date = epoch.add(Duration(days: gameDay));
    return DateFormat('yyyy.MM.dd').format(date.toLocal());
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await Future.wait<dynamic>([
        _client.rpc(
          'get_my_credit_loan_quote',
          params: {'p_product_id': widget.productId, 'p_term_game_days': _term},
        ),
        _client.rpc('get_my_credit_loans'),
        _loadGameEpoch(),
      ]);

      if (!mounted) return;

      setState(() {
        _quote = result[0] is Map
            ? Map<String, dynamic>.from(result[0] as Map)
            : {};

        _loans = result[1] is List
            ? (result[1] as List)
                  .map((value) => Map<String, dynamic>.from(value as Map))
                  .toList()
            : [];

        _gameEpoch = result[2] as DateTime?;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _status(String? status) {
    switch (status) {
      case 'eligible':
        return '가심사 통과 · 실행 시 최종 재심사';

      case 'low_credit_score':
        return '게임 신용점수가 기준에 미달합니다.';

      case 'delinquent':
        return '연체·부도 기록으로 신규 대출이 제한됩니다.';

      case 'existing_credit_loan':
        return '기존 신용대출을 먼저 상환해야 합니다.';

      case 'credit_cooldown':
        return '대출 실행 후 30게임일이 지나야 '
            '재신청할 수 있습니다.';

      case 'below_minimum':
        return '예상 한도가 최소 신청금액보다 낮습니다.';

      case 'invalid_term':
        return '신청할 수 없는 대출 기간입니다.';

      default:
        return '현재 신청할 수 없습니다.';
    }
  }

  Future<bool> _confirm(String title, String content) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title),
        content: Text(content),
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

    return accepted == true;
  }

  Future<void> _issue() async {
    if (_loading || _busy || _quote['status'] != 'eligible') {
      return;
    }

    final amount = int.tryParse(_amountController.text);

    final minimum = _integer(_quote['min_amount']);

    final maximum = _integer(_quote['approval_limit']);

    if (amount == null || amount < minimum || amount > maximum) {
      _message(
        '신청금액은 ${_won(minimum)} ~ '
        '${_won(maximum)} 이내여야 합니다.',
      );
      return;
    }

    final accepted = await _confirm(
      '생활 신용대출 실행',
      '신청금액: ${_won(amount)}\n'
          '대출금리: 연 ${_quote['annual_rate']}%\n'
          '대출기간: 게임 $_term일\n'
          '상환: 게임 30일마다 원리금 상환\n\n'
          '실행하면 생활계좌에 ${_won(amount)}이 '
          '입금되고 같은 금액이 부채로 기록됩니다.\n'
          '대출을 실행하시겠습니까?',
    );

    if (!accepted || !mounted) return;

    _issueKey ??= _uuid();

    setState(() {
      _busy = true;
    });

    try {
      final response = await _client.rpc(
        'issue_basic_credit_loan',
        params: {
          'p_product_id': widget.productId,
          'p_amount': amount,
          'p_term_game_days': _term,
          'p_request_key': _issueKey,
        },
      );

      if (response is! Map || response['success'] != true) {
        throw StateError('대출 실행 결과를 확인할 수 없습니다.');
      }

      _issueKey = null;
      _amountController.clear();

      await _load();

      widget.onChanged?.call();

      _message(
        '대출 실행 완료 · 생활계좌 입금 '
        '${_won(amount)}',
      );
    } catch (e) {
      _message('대출 실행 실패: $e');
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _repay(Map<String, dynamic> loan, String mode) async {
    if (_busy) return;

    int? partAmount;

    if (mode == 'partial_early') {
      final controller = TextEditingController();

      try {
        partAmount = await showDialog<int>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('일부상환 금액 입력'),
            content: TextField(
              controller: controller,
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
                onPressed: () =>
                    Navigator.pop(dialogContext, int.tryParse(controller.text)),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } finally {
        controller.dispose();
      }

      if (partAmount == null || partAmount <= 0) {
        return;
      }

      if (partAmount >= _integer(loan['total_repayment_amount'])) {
        _message(
          '일부상환액은 전체 상환금액보다 '
          '작아야 합니다.',
        );
        return;
      }
    }

    if (!mounted) return;

    final title = switch (mode) {
      'scheduled' => '정기상환',
      'partial_early' => '일부상환',
      _ => '전액상환',
    };

    final accepted = await _confirm(
      title,
      '상환금액은 생활계좌에서 차감됩니다.\n'
      '현재 전체 상환 필요액: '
      '${_won(loan['total_repayment_amount'])}\n'
      '${partAmount == null ? '' : '신청 상환액: ${_won(partAmount)}\n'}'
      '최종 이자는 서버에서 다시 계산합니다. '
      '진행하시겠습니까?',
    );

    if (!accepted || !mounted) return;

    final signature = '${loan['id']}:$mode:${partAmount ?? 0}';

    if (_repaySignature != signature || _repayKey == null) {
      _repaySignature = signature;
      _repayKey = _uuid();
    }

    setState(() {
      _busy = true;
    });

    try {
      final response = await _client.rpc(
        'repay_basic_credit_loan',
        params: {
          'p_loan_id': loan['id'],
          'p_mode': mode,
          'p_request_key': _repayKey,
          'p_amount': partAmount,
        },
      );

      if (response is! Map || response['success'] != true) {
        throw StateError('상환 결과를 확인할 수 없습니다.');
      }

      _repaySignature = null;
      _repayKey = null;

      await _load();

      widget.onChanged?.call();

      _message('${_won(response['payment'])} 상환 완료');
    } catch (e) {
      _message('상환 실패: $e');
      await _load();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loanCard(Map<String, dynamic> loan) {
    final today = _integer(loan['game_day']);

    final due = _integer(loan['next_payment_game_day']);

    final mature = _integer(loan['maturity_game_day']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loan['product_name']?.toString() ?? '생활 신용대출',
            style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
          ),
          const SizedBox(height: 10),
          _infoRow('잔여 원금', _won(loan['outstanding_principal'])),
          _infoRow('발생 이자', _won(loan['interest_due'])),
          _infoRow('전체 상환액', _won(loan['total_repayment_amount'])),
          _infoRow('회차 상환액', _won(loan['scheduled_payment'])),
          _infoRow(
            '다음 상환일',
            '${_gameDate(due)}'
                '${today > due ? ' · 연체' : ''}',
          ),
          _infoRow('대출 만기일', _gameDate(mature)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy || _loading || today < due
                    ? null
                    : () => _repay(loan, 'scheduled'),
                child: const Text('정기상환'),
              ),
              OutlinedButton(
                onPressed: _busy || _loading
                    ? null
                    : () => _repay(loan, 'partial_early'),
                child: const Text('일부상환'),
              ),
              OutlinedButton(
                onPressed: _busy || _loading
                    ? null
                    : () => _repay(loan, 'full_early'),
                child: const Text('전액상환'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator(color: _ink)),
      );
    }

    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '신용대출 정보 조회 오류: '
            '$_error',
          ),
          OutlinedButton(onPressed: _load, child: const Text('다시 조회')),
        ],
      );
    }

    final minimum = _integer(_quote['min_amount']);

    final maximum = _integer(_quote['approval_limit']);

    final available = _quote['status'] == 'eligible' && maximum >= minimum;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '내 생활 신용대출',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        const SizedBox(height: 12),

        if (_loans.isEmpty)
          const Text(
            '현재 이용 중인 신용대출이 없습니다.',
            style: TextStyle(fontSize: 13, color: _muted),
          )
        else
          for (final loan in _loans) _loanCard(loan),

        const Divider(height: 30, color: _line),

        const Text(
          '신규 신용대출 신청',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        const SizedBox(height: 12),

        _infoRow('게임 신용점수', '${_quote['credit_score'] ?? '-'}점'),
        _infoRow('대출금리', '연 ${_quote['annual_rate'] ?? '-'}%'),
        _infoRow('예상 승인한도', _won(maximum)),
        _infoRow('최소 신청금액', _won(minimum)),

        Text(
          _status(_quote['status']?.toString()),
          style: const TextStyle(fontSize: 12, color: _muted, height: 1.5),
        ),

        const SizedBox(height: 14),

        const Text(
          '대출기간 (게임 기준)',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final days in const [30, 60, 90, 120, 150, 180])
              ChoiceChip(
                label: Text('${days ~/ 30}개월'),
                selected: _term == days,
                onSelected: _busy
                    ? null
                    : (selected) {
                        if (!selected) return;

                        _term = days;
                        _issueKey = null;
                        _load();
                      },
                showCheckmark: false,
              ),
          ],
        ),

        const SizedBox(height: 14),

        TextField(
          controller: _amountController,
          enabled: available && !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: '신청금액 (원)',
            hintText: available ? '최대 ${_won(maximum)}' : '현재 신청할 수 없습니다',
            border: const OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 12),

        FilledButton(
          onPressed: available && !_busy ? _issue : null,
          style: FilledButton.styleFrom(backgroundColor: _ink),
          child: Text(_busy ? '처리 중...' : '신용대출 신청 및 실행'),
        ),

        const SizedBox(height: 12),

        const Text(
          '직업·급여는 필수가 아닙니다. '
          '게임 신용점수, 기존 대출 및 연체 이력, '
          '검증된 현금흐름으로 대출 한도를 계산합니다. '
          '실행 시 조건을 재검증합니다.',
          style: TextStyle(fontSize: 12, color: _muted, height: 1.5),
        ),
      ],
    );
  }
}
