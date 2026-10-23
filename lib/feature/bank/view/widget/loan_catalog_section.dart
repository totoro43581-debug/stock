
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/bank/view/widget/deposit_secured_loan_section.dart';

class LoanCatalogSection extends StatefulWidget {
  final VoidCallback? onChanged;

  const LoanCatalogSection({
    super.key,
    this.onChanged,
  });

  @override
  State<LoanCatalogSection> createState() =>
      _LoanCatalogSectionState();
}

class _LoanCatalogSectionState extends State<LoanCatalogSection> {
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _line = Color(0xFFE5E7EB);
  static const Color _soft = Color(0xFFF9FAFB);

  final NumberFormat _format = NumberFormat('#,##0');

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
    return '${_format.format(_number(value).round())}원';
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;

      final offersResponse =
      await client.rpc('get_my_loan_offers');

      final overviewResponse =
      await client.rpc('get_my_loan_overview');

      final offers = (offersResponse as List)
          .map(
            (item) => Map<String, dynamic>.from(item as Map),
      )
          .toList();

      final overview = overviewResponse is Map
          ? Map<String, dynamic>.from(overviewResponse)
          : <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        _offers = offers;
        _overview = overview;
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

  Map<String, dynamic> get _clock {
    final value = _overview['game_clock'];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  String get _gameDate {
    final raw = _clock['game_datetime']?.toString();
    if (raw == null) return '조회 전';

    final date = DateTime.tryParse(raw);

    if (date == null) return '조회 전';

    return DateFormat('yyyy.MM.dd HH:mm')
        .format(date.toLocal());
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

  String _repayment(String type) {
    switch (type) {
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
        return type;
    }
  }

  String _earlyRepayment(Map<String, dynamic> offer) {
    final type =
        offer['early_repayment_policy']?.toString() ?? '';

    switch (type) {
      case 'free':
        return '자유 중도상환 · 수수료 없음';

      case 'fee':
        final fee =
            _number(offer['early_repayment_fee_rate']) * 100;
        final days =
        _number(offer['fee_period_game_days']).toInt();

        return '중도상환 가능 · 기준 수수료 '
            '${fee.toStringAsFixed(2)}% '
            '· 적용기간 게임 $days일';

      case 'partial_limited':
        final ratio = _number(
          offer['partial_repayment_limit_ratio'],
        ) *
            100;

        return '일부상환 한도 '
            '${ratio.toStringAsFixed(0)}% · '
            '전액상환 조건 별도 확인';

      case 'lock_period':
        final days =
        _number(offer['lock_period_game_days']).toInt();

        return '초기 게임 $days일 조기상환 제한형';

      default:
        return '중도상환 조건 확인 필요';
    }
  }

  String _precheckMessage(String? code) {
    switch (code) {
      case 'precheck_possible':
        return '기본 가심사 조건 충족 · 최종 승인 아님';
      case 'income_not_verified':
        return '게임 소득정보 검증 필요';
      case 'credit_not_set':
        return '게임 신용점수 산정 필요';
      case 'low_credit_score':
        return '상품 신용점수 기준 미달';
      case 'insufficient_collateral':
        return '인정 가능한 예금담보 부족';
      case 'limit_below_minimum':
        return '예상한도가 최소 대출금액보다 낮음';
      case 'property_not_connected':
        return '부동산 보유·담보 시스템 연동 전';
      case 'business_not_connected':
        return '사업자·사업소득 시스템 연동 전';
      default:
        return '심사정보 미확인';
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

  Widget _surface({
    required Widget child,
  }) {
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

  Widget _summaryCard(String label, String value) {
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _muted,
            ),
          ),
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
      child: Column(
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
                tooltip: '새로고침',
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 950
                  ? 4
                  : width >= 560
                  ? 2
                  : 1;

              final cardWidth =
                  (width - 12 * (columns - 1)) / columns;

              final cards = [
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
                  '게임 연 소득',
                  verified && income != null
                      ? _won(income)
                      : '검증된 소득 없음',
                ),
              ];

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final card in cards)
                    SizedBox(
                      width: cardWidth,
                      child: card,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            '게임 시간  D+${_number(_clock['game_day']).toInt()} '
                '· $_gameDate',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            '현실 1초 = 게임 1분 / 게임 하루 = 현실 24분\n'
                '현재 기존 예금·적금은 현실 시간으로 운영 중입니다.',
            style: TextStyle(
              fontSize: 12,
              color: _muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        '$label  $value',
        style: const TextStyle(
          fontSize: 12,
          height: 1.35,
          color: _ink,
        ),
      ),
    );
  }


  Future<void> _openDepositLoanDialog() async {
    if (!mounted) return;

    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: _ink,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
            canvasColor: Colors.white,
          ),
          child: Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 680,
              height: MediaQuery.sizeOf(dialogContext).height * 0.85,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '예금담보대출 신청·상환',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: DepositSecuredLoanSection(
                        onChanged: () {
                          Navigator.of(dialogContext).pop();

                          if (mounted) {
                            _load();
                            widget.onChanged?.call();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  String _compactMoney(dynamic value) {
    final amount = _number(value).round();

    if (amount >= 100000000) {
      final eok = amount ~/ 100000000;
      final man = (amount % 100000000) ~/ 10000;

      if (man == 0) {
        return '${_format.format(eok)}억원';
      }

      return '${_format.format(eok)}억 '
          '${_format.format(man)}만원';
    }

    if (amount >= 10000) {
      return '${_format.format(amount ~/ 10000)}만원';
    }

    return _won(amount);
  }

  String _compactTerm(int days) {
    if (days <= 0) return '-';
    if (days == 7) return '1주일';

    if (days % 365 == 0) {
      return '${days ~/ 365}년';
    }

    if (days % 30 == 0 && days < 365) {
      return '${days ~/ 30}개월';
    }

    return '$days일';
  }

  Future<void> _showLoanDetails(
      Map<String, dynamic> offer,
      ) async {
    if (!mounted) return;

    final loanType = offer['loan_type']?.toString() ?? '';
    final isDepositLoan = loanType == 'deposit_secured';
    final canApply =
        isDepositLoan && offer['is_active'] == true;

    bool showApplication = false;

    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Theme(
              data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(
                  primary: _ink,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                ),
                canvasColor: Colors.white,
              ),
              child: Dialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                insetPadding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SizedBox(
                  width: 640,
                  height:
                  MediaQuery.sizeOf(dialogContext).height *
                      0.82,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          18, 10, 10, 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                showApplication
                                    ? '예금담보대출 신청·상환'
                                    : '대출상품 상세',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '닫기',
                              onPressed: () {
                                Navigator.of(dialogContext)
                                    .pop();
                              },
                              icon: const Icon(
                                Icons.close,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(
                        height: 1,
                        color: _line,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: showApplication
                              ? DepositSecuredLoanSection(
                            onChanged: () {
                              Navigator.of(dialogContext)
                                  .pop();

                              if (mounted) {
                                _load();
                                widget.onChanged?.call();
                              }
                            },
                          )
                              : Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                offer['bank_name']
                                    ?.toString() ??
                                    '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                offer['product_name']
                                    ?.toString() ??
                                    '',
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight:
                                  FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _loanType(loanType),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '연 ${_number(offer['annual_rate']).toStringAsFixed(2)}%',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight:
                                  FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                              const Divider(height: 30),
                              _detail(
                                '상품 최대한도',
                                _won(offer['max_amount']),
                              ),
                              _detail(
                                '최소 신청금액',
                                _won(offer['min_amount']),
                              ),
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
                                  offer['repayment_method']
                                      ?.toString() ??
                                      '',
                                ),
                              ),
                              if (offer['min_credit_score'] !=
                                  null)
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
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _earlyRepayment(offer),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                  height: 1.5,
                                ),
                              ),
                              const Divider(height: 28),
                              const Text(
                                '개인 가심사',
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                offer['indicative_limit'] ==
                                    null
                                    ? '예상한도: 미산정'
                                    : '예상한도: '
                                    '${_won(offer['indicative_limit'])}',
                                style: const TextStyle(
                                  fontWeight:
                                  FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _precheckMessage(
                                  offer['precheck_status']
                                      ?.toString(),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!showApplication) ...[
                        const Divider(
                          height: 1,
                          color: _line,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.of(dialogContext)
                                      .pop();
                                },
                                child: const Text('닫기'),
                              ),
                              const Spacer(),
                              if (canApply)
                                FilledButton(
                                  onPressed: () {
                                    setModalState(() {
                                      showApplication = true;
                                    });
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _ink,
                                    foregroundColor: Colors.white,
                                  ),
                                  child:
                                  const Text('대출 신청·상환'),
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
            );
          },
        );
      },
    );
  }


  Widget _offerCard(Map<String, dynamic> offer) {
    final name = offer['product_name']?.toString() ?? '';
    final bank = offer['bank_name']?.toString() ?? '';
    final type = offer['loan_type']?.toString() ?? '';

    final rate = _number(offer['annual_rate']);

    final minTerm =
    _number(offer['min_term_game_days']).toInt();
    final maxTerm =
    _number(offer['max_term_game_days']).toInt();

    final canApply =
        type == 'deposit_secured' &&
            offer['is_active'] == true;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showLoanDetails(offer),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 12,
          ),
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
                      style: const TextStyle(
                        fontSize: 11,
                        color: _muted,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 17,
                    color: _muted,
                  ),
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
                        color: _ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${rate.toStringAsFixed(2)}%',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(
                height: 1,
                color: _line,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '최대한도',
                          style: TextStyle(
                            fontSize: 10,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _compactMoney(offer['max_amount']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '대출기간',
                          style: TextStyle(
                            fontSize: 10,
                            color: _muted,
                          ),
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
                            color: _ink,
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
                      _repayment(
                        offer['repayment_method']
                            ?.toString() ??
                            '',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    canApply ? '신청 가능' : '준비 중',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: canApply ? _ink : _muted,
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

    final visible =
    _offers.where(_matchesCategory).toList();

    return _surface(
      child: Column(
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
          const SizedBox(height: 7),
          Text(
            '전체 ${_offers.length}개 상품 · '
                '심사정보에 따라 예상한도가 달라집니다.',
            style: const TextStyle(
              fontSize: 12,
              color: _muted,
            ),
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in categories) ...[
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _category = category.$1;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                      _category == category.$1
                          ? _ink
                          : Colors.white,
                      foregroundColor:
                      _category == category.$1
                          ? Colors.white
                          : _ink,
                      side: const BorderSide(color: _line),
                    ),
                    child: Text(category.$2),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 1160
                  ? 5
                  : width >= 900
                  ? 4
                  : width >= 680
                  ? 3
                  : width >= 430
                  ? 2
                  : 1;

              final cardWidth =
                  (width - 10 * (columns - 1)) / columns;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final offer in visible)
                    SizedBox(
                      width: cardWidth,
                      child: _offerCard(offer),
                    ),
                ],
              );
            },
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
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(
            color: _ink,
          ),
        ),
      );
    }

    if (_error != null) {
      return _surface(
        child: Column(
          children: [
            Text(
              _error!,
              style: const TextStyle(color: _ink),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              child: const Text('다시 조회'),
            ),
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

        // 4. 대출 안내
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '※ 예금담보대출은 신청 및 상환 기능을 이용할 수 있습니다. '
                '나머지 대출상품은 심사 및 실행 기능을 개발 중입니다. '
                '예상한도는 최종 승인금액이 아닙니다.',
            style: TextStyle(
              fontSize: 12,
              color: _muted,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
