import 'package:stock/feature/bank/view/widget/loan_auto_repayment_notice.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/bank/repository/bank_repository.dart';
import 'package:stock/core/game_time/game_time_service.dart';

class DepositSecuredLoanSection extends StatefulWidget {
  final VoidCallback? onChanged;
  final bool manageOnly;
  final String? loanId;

  const DepositSecuredLoanSection({
    super.key,
    this.onChanged,
    this.manageOnly = false,
    this.loanId,
  });

  @override
  State<DepositSecuredLoanSection> createState() =>
      _DepositSecuredLoanSectionState();
}

class _DepositSecuredLoanSectionState extends State<DepositSecuredLoanSection> {
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF4B5563);
  static const line = Color(0xFFE5E7EB);

  final client = Supabase.instance.client;
  final money = NumberFormat('#,##0');
  final amountController = TextEditingController();

  bool loading = true;
  bool requestInFlight = false;
  bool refreshQueued = false;
  bool working = false;
  String? error;

  Map<String, dynamic>? product;
  Map<String, dynamic> clock = {};

  List<Map<String, dynamic>> deposits = [];
  List<Map<String, dynamic>> loans = [];
  GameClockMapping? clockMapping;
  Timer? deadlineTimer;

  String? selectedDepositId;
  int selectedTerm = 10;

  @override
  void initState() {
    super.initState();
    load();
    deadlineTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (widget.manageOnly && timer.tick % 60 == 0 && !loading && !working) {
        load(showLoading: false);
      } else if (!loading && loans.isNotEmpty) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    deadlineTimer?.cancel();
    amountController.dispose();
    super.dispose();
  }

  double number(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String won(dynamic value) {
    return '${money.format(number(value).ceil())}원';
  }

  String newRequestKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final value = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  void message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> load({bool showLoading = true}) async {
    if (!mounted) return;
    if (requestInFlight) {
      refreshQueued = true;
      return;
    }
    requestInFlight = true;

    setState(() {
      if (showLoading) loading = true;
      error = null;
    });

    try {
      if (widget.manageOnly) {
        final results = await Future.wait<dynamic>([
          client.rpc('get_my_deposit_secured_loans'),
          readGameEpoch(),
        ]);
        if (results[0] is! List) {
          throw const FormatException('대출 목록 응답을 확인할 수 없습니다.');
        }
        if (!mounted) return;
        setState(() {
          loans = (results[0] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .where(
                (loan) =>
                    widget.loanId == null ||
                    loan['id'].toString() == widget.loanId,
              )
              .toList();
          clockMapping = results[1] as GameClockMapping?;
          loading = false;
        });
        return;
      }
      final results = await Future.wait<dynamic>([
        client
            .from('loan_products')
            .select(
              'id,bank_id,product_name,annual_rate,min_amount,'
              'max_amount,max_ltv,min_term_game_days,'
              'max_term_game_days',
            )
            .eq('product_code', 'LOAN_DEPOSIT_SECURED')
            .eq('is_active', true),
        client
            .from('user_bank_accounts')
            .select('*')
            .eq('status', 'active')
            .eq('product_type', 'deposit'),
        client.rpc('get_my_deposit_secured_loans'),
        client.rpc('get_game_clock'),
        readGameEpoch(),
      ]);

      final products = List<Map<String, dynamic>>.from(results[0] as List);

      // 현재 선택한 대출상품의 소속 은행
      final String? loanBankId = products.isNotEmpty
          ? products.first['bank_id']?.toString()
          : null;

      // 해당 은행에서 발행한 예금상품만 조회
      final List<Map<String, dynamic>> bankDepositProducts = loanBankId == null
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await client
                  .from('bank_products')
                  .select('id')
                  .eq('bank_id', loanBankId),
            );

      // 담보로 인정할 수 있는 예금상품 ID
      final Set<String> allowedProductIds = bankDepositProducts
          .map((item) => item['id'].toString())
          .toSet();

      // 가입 예금 중 같은 은행 상품만 표시
      final List<Map<String, dynamic>> fetchedDeposits =
          List<Map<String, dynamic>>.from(results[1] as List).where((item) {
            return allowedProductIds.contains(item['product_id']?.toString());
          }).toList();

      final fetchedLoans = (results[2] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      final fetchedClock = Map<String, dynamic>.from(results[3] as Map);

      if (!mounted) return;

      setState(() {
        product = products.isEmpty ? null : products.first;
        deposits = fetchedDeposits;
        loans = fetchedLoans;
        clock = fetchedClock;
        clockMapping = results[4] as GameClockMapping?;

        if (!deposits.any((item) => item['id'] == selectedDepositId)) {
          selectedDepositId = deposits.isEmpty
              ? null
              : deposits.first['id'].toString();
        }

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    } finally {
      requestInFlight = false;
      if (refreshQueued && mounted) {
        refreshQueued = false;
        unawaited(load(showLoading: false));
      }
    }
  }

  Future<GameClockMapping?> readGameEpoch() =>
      BankRepository().fetchClockMapping();

  String gameDate(dynamic day) {
    final value = int.tryParse(day?.toString() ?? '');
    return realDeadlineLabel(
      value == null || value < 0
          ? null
          : clockMapping?.realTimeForGameDay(value),
    );
  }

  Map<String, dynamic>? get selectedDeposit {
    for (final item in deposits) {
      if (item['id'] == selectedDepositId) {
        return item;
      }
    }
    return null;
  }

  bool get depositIsPledged {
    return loans.any((loan) => loan['deposit_account_id'] == selectedDepositId);
  }

  double get availableLimit {
    if (product == null || selectedDeposit == null) {
      return 0;
    }

    if (depositIsPledged) return 0;

    final principal = number(selectedDeposit!['principal_amount']);
    final ratio = number(product!['max_ltv']);
    final maxAmount = number(product!['max_amount']);

    return min(maxAmount, (principal * ratio).floorToDouble());
  }

  List<int> get validTerms {
    if (product == null || selectedDeposit == null) {
      return [];
    }

    final maturity = DateTime.tryParse(
      selectedDeposit!['maturity_at']?.toString() ?? '',
    );

    if (maturity == null) return [];

    final usesGameTime = selectedDeposit!['time_model'] == 'virtual';
    final secondsPerGameDay = usesGameTime
        ? 86400.0
        : number(clock['real_seconds_per_game_day']);
    if (secondsPerGameDay <= 0) return [];
    final currentTime = usesGameTime
        ? DateTime.tryParse(clock['game_datetime']?.toString() ?? '')
        : DateTime.now();
    if (currentTime == null) return [];
    final remainingSeconds = maturity.difference(currentTime).inSeconds;

    final minimum = number(product!['min_term_game_days']).toInt();

    final maximum = number(product!['max_term_game_days']).toInt();

    const options = [10, 30, 60, 90, 180, 365];

    return options.where((days) {
      return days >= minimum &&
          days <= maximum &&
          remainingSeconds >= days * secondsPerGameDay;
    }).toList();
  }

  Future<bool> confirm(String title, String content) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
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
              child: const Text('확인'),
            ),
          ],
        );
      },
    );

    return answer == true;
  }

  Future<void> issueLoan() async {
    if (working || product == null || selectedDeposit == null) {
      return;
    }

    final amount = int.tryParse(amountController.text.trim());
    final terms = validTerms;

    if (amount == null ||
        amount < number(product!['min_amount']) ||
        amount > availableLimit) {
      message('최소 신청금액과 예금담보 대출한도를 확인해 주세요.');
      return;
    }

    if (!terms.contains(selectedTerm)) {
      message('예금 만기 이내의 대출기간을 선택해 주세요.');
      return;
    }

    final rate = number(product!['annual_rate']);
    final expectedInterest = (amount * rate / 100 * selectedTerm / 365).ceil();

    final approved = await confirm(
      '예금담보대출 실행',
      '신청금액: ${won(amount)}\n'
          '금리: 연 ${rate.toStringAsFixed(2)}%\n'
          '기간: 게임 $selectedTerm일\n'
          '예상 만기이자: ${won(expectedInterest)}\n\n'
          '대출금은 생활계좌에 입금됩니다.\n'
          '대출을 전액 상환하기 전에는 담보 예금을 '
          '중도해지하거나 만기수령할 수 없습니다.\n\n'
          '대출을 실행하시겠습니까?',
    );

    if (!approved || !mounted) return;

    setState(() => working = true);

    try {
      final result = await client.rpc(
        'issue_deposit_secured_loan',
        params: {
          'p_product_id': product!['id'],
          'p_deposit_account_id': selectedDepositId,
          'p_amount': amount,
          'p_term_game_days': selectedTerm,
          'p_request_key': newRequestKey(),
        },
      );

      if (!mounted) return;

      amountController.clear();
      await load();
      widget.onChanged?.call();

      message('대출 실행 완료: ${won((result as Map)['principal_amount'])}');
    } catch (e) {
      if (!mounted) return;
      message('대출 실행 실패: $e');
      await load();
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> repayLoan(
    Map<String, dynamic> loan, {
    required bool full,
  }) async {
    if (working) return;

    double? paymentAmount;

    if (!full) {
      final controller = TextEditingController();

      final entered = await showDialog<double>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('일부상환'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: '상환금액',
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
                dialogContext,
                double.tryParse(controller.text),
              ),
              child: const Text('확인'),
            ),
          ],
        ),
      );

      controller.dispose();

      if (entered == null || entered <= 0) return;
      paymentAmount = entered;
    }

    if (!mounted) return;

    final approved = await confirm(
      full ? '대출 전액상환' : '대출 일부상환',
      full
          ? '표시된 예상 상환액은 ${won(loan['full_repayment_amount'])}입니다.\n'
                '최종 금액은 실행 시점의 게임 이자로 다시 계산됩니다.\n'
                '생활계좌에서 상환하시겠습니까?'
          : '${won(paymentAmount)}을 생활계좌에서 상환하시겠습니까?\n'
                '미납 이자가 있으면 이자부터 충당됩니다.',
    );

    if (!approved || !mounted) return;

    setState(() => working = true);

    try {
      final result = await client.rpc(
        'repay_deposit_secured_loan',
        params: {
          'p_loan_id': loan['id'],
          'p_payment_amount': full ? null : paymentAmount,
        },
      );

      if (!mounted) return;

      await load();
      widget.onChanged?.call();

      message('상환 완료: ${won((result as Map)['payment'])}');
    } catch (e) {
      if (!mounted) return;
      message('상환 실패: $e');
      await load();
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Widget _panel(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _loanCard(Map<String, dynamic> loan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loan['product_name']?.toString() ?? '예금담보대출',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 440
                  ? (constraints.maxWidth - 20) / 2
                  : constraints.maxWidth;
              final details = <(String, String)>[
                ('잔여 원금', won(loan['outstanding_principal'])),
                ('발생 이자', won(loan['accrued_interest'])),
                ('전체 상환 예상액', won(loan['full_repayment_amount'])),
                ('만기 예정 · 한국시간', gameDate(loan['maturity_game_day'])),
              ];
              return Wrap(
                spacing: 20,
                runSpacing: 16,
                children: [
                  for (final (label, value) in details)
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(fontSize: 14, color: muted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LoanAutoRepaymentNotice(loan: loan, isCredit: false),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: working ? null : () => repayLoan(loan, full: false),
                child: const Text('일부상환'),
              ),
              FilledButton(
                onPressed: working ? null : () => repayLoan(loan, full: true),
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
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator(color: ink)),
      );
    }

    if (error != null) {
      return _panel(
        '대출 조회 오류',
        Column(
          children: [
            Text(error!),
            OutlinedButton(onPressed: load, child: const Text('다시 조회')),
          ],
        ),
      );
    }

    final terms = validTerms;
    final effectiveTerm = terms.contains(selectedTerm)
        ? selectedTerm
        : terms.isEmpty
        ? null
        : terms.first;

    final canApply =
        product != null &&
        selectedDeposit != null &&
        !depositIsPledged &&
        availableLimit >= number(product!['min_amount']) &&
        effectiveTerm != null;

    if (widget.manageOnly) {
      return _panel(
        '예금담보대출 상환',
        loans.isEmpty
            ? const Text('선택한 대출은 현재 이용 중 목록에 없습니다.')
            : Column(children: [for (final loan in loans) _loanCard(loan)]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          '내 예금담보대출',
          loans.isEmpty
              ? const Text(
                  '현재 이용 중인 예금담보대출이 없습니다.',
                  style: TextStyle(color: muted),
                )
              : Column(children: [for (final loan in loans) _loanCard(loan)]),
        ),
        const SizedBox(height: 14),
        _panel(
          '예금담보대출 신청',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '가입 중인 예금을 담보로 생활계좌에 자금을 '
                '입금받습니다. 대출한도는 해당 예금 원금의 '
                '최대 90%이며, 이 상품은 중도상환수수료가 없습니다.',
                style: TextStyle(fontSize: 14, color: muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              if (product == null)
                const Text('현재 신청 가능한 상품이 없습니다.')
              else if (deposits.isEmpty)
                const Text('해당 은행에 담보로 사용할 활성 예금이 없습니다.')
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: selectedDepositId,
                  decoration: const InputDecoration(
                    labelText: '담보 예금',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final item in deposits)
                      DropdownMenuItem(
                        value: item['id'].toString(),
                        child: Text(
                          '${item['product_name_snapshot']} '
                          '· ${won(item['principal_amount'])}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: working
                      ? null
                      : (value) {
                          setState(() {
                            selectedDepositId = value;
                          });
                        },
                ),
                const SizedBox(height: 12),
                Text(
                  depositIsPledged
                      ? '이미 대출 담보로 사용 중인 예금입니다.'
                      : '현재 담보 기준 최대 ${won(availableLimit)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountController,
                  enabled: canApply && !working,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: '신청금액 (원)',
                    hintText: canApply
                        ? '최대 ${won(availableLimit)}'
                        : '대출 조건을 확인하세요',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<int>(
                  initialValue: effectiveTerm,
                  isExpanded: true,
                  menuMaxHeight: 192,
                  itemHeight: 48,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  style: const TextStyle(fontSize: 14, color: ink),
                  decoration: const InputDecoration(
                    labelText: '대출기간 (게임 일수)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final term in terms)
                      DropdownMenuItem<int>(
                        value: term,
                        child: Text('게임 $term일'),
                      ),
                  ],
                  onChanged: !canApply || working
                      ? null
                      : (value) {
                          setState(() {
                            selectedTerm = value ?? selectedTerm;
                          });
                        },
                ),

                const SizedBox(height: 15),
                FilledButton(
                  onPressed: !canApply || working
                      ? null
                      : () {
                          selectedTerm = effectiveTerm;
                          issueLoan();
                        },
                  child: Text(working ? '처리 중...' : '대출 신청 및 실행'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
