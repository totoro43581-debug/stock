
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:stock/feature/asset_account/repository/asset_account_repository.dart';
import 'package:stock/feature/asset_account/view/widget/asset_account_transfer_widget.dart';
import 'package:stock/feature/asset_account/view/widget/asset_transaction_list_widget.dart';
import 'package:stock/feature/bank/model/bank_product_model.dart';
import 'package:stock/feature/bank/model/user_bank_account_model.dart';
import 'package:stock/feature/bank/repository/bank_repository.dart';
import 'package:stock/feature/bank/view/widget/loan_catalog_section.dart';
import 'package:stock/core/game_time/game_time_service.dart';


class BankScreen extends StatefulWidget {
  const BankScreen({super.key});

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _background = Color(0xFFF3F5F9);

  final BankRepository _bankRepository = BankRepository();
  final AssetAccountRepository _assetRepository =
  AssetAccountRepository();
  final NumberFormat _number = NumberFormat('#,##0');

  String _tab = 'account';
  String _historyPeriod = 'recent';

  bool _loading = true;
  bool _working = false;
  String? _error;
  String? _historyError;
  bool _refreshingActivity = false;

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _transactions = [];
  List<BankProductModel> _deposits = [];
  List<BankProductModel> _savings = [];
  List<UserBankAccountModel> _myProducts = [];
  GameClockSnapshot? _gameClock;
  GameClockMapping? _clockMapping;
  bool? _newProductsUseGameTime;
  bool _syncingClock = false;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (timer.tick % 60 == 0 && !_loading) {
        _syncGameClock();
        if (_tab == 'history') _refreshBankActivity();
      } else if (_myProducts.isNotEmpty) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncGameClock() async {
    if (_syncingClock) return;
    _syncingClock = true;
    try {
      final data = await _bankRepository.fetchGameClock();
      final snapshot = GameClockSnapshot.fromMap(data);
      final mapping = await _bankRepository.fetchClockMapping();
      if (!mounted) return;
      setState(() {
        _gameClock = snapshot;
        _clockMapping = mapping;
        _newProductsUseGameTime = data['bank_products_time_model'] == 'virtual';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gameClock = null;
        _clockMapping = null;
        _newProductsUseGameTime = null;
      });
    } finally {
      _syncingClock = false;
    }
  }

  String _productDeadline(UserBankAccountModel item, DateTime time) {
    final deadline = item.usesGameTime ? _clockMapping?.realTimeForGameTime(time) : time.toUtc();
    return realDeadlineLabel(deadline);
  }

  String _termLabel(int days) {
    if (_newProductsUseGameTime == null) return '$days일 (시간 기준 조회 실패)';
    return '$days${_newProductsUseGameTime! ? '게임일' : '일(현실)'}';
  }

  Future<void> _loadData({
    bool showLoading = true,
  }) async {
    if (showLoading && mounted) {
      setState(() => _loading = true);
    }

    try {
      await _syncGameClock();
      await _assetRepository.ensureUserAssetAccounts();

      final accounts =
      await _assetRepository.fetchUserAssetAccounts();

      final transactions = await _assetRepository.fetchBankAccountTransactions();

      final deposits =
      await _bankRepository.fetchDepositProducts();

      final savings =
      await _bankRepository.fetchSavingsProducts();

      final myProducts =
      await _bankRepository.fetchMyActiveBankAccounts();

      if (!mounted) return;

      setState(() {
        _accounts = accounts
            .where(
              (a) => const [
            'bank',
            'stock',
            'coin',
          ].contains(a['account_type']),
        )
            .toList();

        _transactions = transactions;
        _historyError = null;
        _deposits = deposits;
        _savings = savings;
        _myProducts = myProducts;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _money(num value) {
    return '${_number.format(value.floor())}원';
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  String _accountLabel(String type) {
    switch (type) {
      case 'bank':
        return '생활계좌';

      case 'stock':
        return '주식투자계좌';

      case 'coin':
        return '코인투자계좌';

      default:
        return type;
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
        ),
      );
  }

  Future<void> _perform(
      Future<void> Function() operation,
      String successMessage,
      ) async {
    if (_working) return;

    setState(() => _working = true);

    try {
      await operation();

      await _loadData(showLoading: false);

      _message(successMessage);
    } catch (e) {
      _message(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<bool> _confirm(
      String title,
      String content,
      ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _joinProduct(
      BankProductModel product,
      ) async {
    if (_working) return;

    final controller = TextEditingController();

    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            product.isDeposit ? '예금 가입' : '적금 가입',
          ),
          content: SizedBox(
            width: 390,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '연 ${product.annualRate.toStringAsFixed(2)}% · ${_termLabel(product.termDays)}',
                  style: const TextStyle(
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: product.isDeposit
                        ? '가입 금액 (원)'
                        : '1회 납입 금액 (원)',
                    hintText: '숫자만 입력',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '최소 ${_money(product.minAmount)} · '
                      '최대 ${product.maxAmount == null ? '제한 없음' : _money(product.maxAmount!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  double.tryParse(controller.text),
                );
              },
              child: const Text('가입'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || amount == null) return;

    if (amount <= 0 ||
        amount < product.minAmount ||
        (product.maxAmount != null &&
            amount > product.maxAmount!)) {
      _message('상품의 최소·최대 가입 금액을 확인해 주세요.');
      return;
    }

    await _perform(
          () async {
        if (product.isDeposit) {
          await _bankRepository.openDeposit(
            productId: product.id,
            amount: amount,
          );
        } else {
          await _bankRepository.openSavings(
            productId: product.id,
            installmentAmount: amount,
          );
        }
      },
      '${product.isDeposit ? '예금' : '적금'} 가입이 완료되었습니다.',
    );
  }

  Future<void> _payInstallment(
      UserBankAccountModel item,
      ) async {
    final confirmed = await _confirm(
      '적금 납입',
      '${item.productNameSnapshot}의 다음 회차를 납입하시겠습니까?',
    );

    if (!confirmed) return;

    await _perform(
          () async {
        await _bankRepository.paySavingsInstallment(
          accountId: item.id,
        );
      },
      '적금 납입이 완료되었습니다.',
    );
  }

  Future<void> _claim(
      UserBankAccountModel item,
      ) async {
    final confirmed = await _confirm(
      '만기 수령',
      '${item.productNameSnapshot}의 만기 금액을 수령하시겠습니까?',
    );

    if (!confirmed) return;

    await _perform(
          () async {
        await _bankRepository.claimBankProductAccount(
          accountId: item.id,
        );
      },
      '만기 수령이 완료되었습니다.',
    );
  }

  Future<void> _cancel(
      UserBankAccountModel item,
      ) async {
    final confirmed = await _confirm(
      '중도해지',
      '${item.productNameSnapshot}을(를) 중도해지하시겠습니까? '
          '이자가 감액될 수 있습니다.',
    );

    if (!confirmed) return;

    await _perform(
          () async {
        await _bankRepository.cancelBankProductAccount(
          accountId: item.id,
        );
      },
      '중도해지가 완료되었습니다.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: _ink,
          secondary: _ink,
          primaryContainer: const Color(0xFFF3F4F6),
          surface: Colors.white,
        ),
      ),
      child: Container(
        color: _background,
        child: _loading
            ? const Center(
          child: CircularProgressIndicator(
            color: _ink,
          ),
        )
            : RefreshIndicator(
          onRefresh: () {
            return _loadData(showLoading: false);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1400,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    const SizedBox(height: 14),
                    _navigation(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _panel(
                        '조회 오류',
                        _error!,
                        OutlinedButton(
                          onPressed: _loadData,
                          child: const Text('다시 불러오기'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (_tab == 'account') _accountTab(),
                    if (_tab == 'deposit')
                      _productTab('deposit'),
                    if (_tab == 'savings')
                      _productTab('savings'),
                    if (_tab == 'loan') _loanTab(),
                    if (_tab == 'history') _historyTab(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final totalCash = _accounts.fold<double>(
      0,
          (sum, account) =>
      sum + _num(account['cash_balance']),
    );

    return _panel(
      '은행',
      '생활계좌·투자계좌 이체와 예금·적금 금융상품을 관리합니다.',
      Row(
        children: [
          const Icon(
            Icons.account_balance_outlined,
            size: 18,
            color: _muted,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '계좌 잔액 합계 ${_money(totalCash)}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '새로고침',
            onPressed: _working
                ? null
                : () => _loadData(
              showLoading: false,
            ),
            icon: const Icon(
              Icons.refresh_rounded,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigation() {
    const tabs = [
      ('account', '계좌·이체'),
      ('deposit', '예금'),
      ('savings', '적금'),
      ('loan', '대출'),
      ('history', '거래내역'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs) ...[
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _tab = tab.$1;
                });
                if (tab.$1 == 'history') _refreshBankActivity();
              },
              style: OutlinedButton.styleFrom(
                backgroundColor:
                _tab == tab.$1 ? _ink : Colors.white,
                foregroundColor:
                _tab == tab.$1 ? Colors.white : _ink,
                side: BorderSide(
                  color: _tab == tab.$1 ? _ink : _border,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                tab.$2,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _panel(
      String title,
      String subtitle,
      Widget child,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: _muted,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 34,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _muted,
        ),
      ),
    );
  }

  Widget _responsiveCards(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;

        final columns = available >= 900
            ? 3
            : available >= 560
            ? 2
            : 1;

        final width =
            (available - 12 * (columns - 1)) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: card,
              ),
          ],
        );
      },
    );
  }

  Widget _smallCard(Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _border,
        ),
      ),
      child: content,
    );
  }

  Widget _accountTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          '내 계좌',
          '사용 중인 3개 계좌의 현금 잔액입니다. '
              '부동산 투자계좌는 제외합니다.',
          _accounts.isEmpty
              ? _empty('조회 가능한 계좌가 없습니다.')
              : _responsiveCards(
            _accounts.map((item) {
              final type =
                  item['account_type']?.toString() ?? '';

              return _smallCard(
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      _accountLabel(type),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _money(
                          _num(item['cash_balance']),
                        ),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '사용 가능 현금',
                      style: TextStyle(
                        fontSize: 12,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        AssetAccountTransferWidget(
          onTransferCompleted: () {
            _loadData(showLoading: false);
          },
        ),
      ],
    );
  }

  Widget _productTab(String type) {
    final isDeposit = type == 'deposit';
    final title = isDeposit ? '예금' : '적금';

    final products =
    isDeposit ? _deposits : _savings;

    final mine = _myProducts.where((account) {
      return isDeposit
          ? account.isDeposit
          : account.isSavings;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          '내 $title',
          '가입한 상품의 원금·만기·납입 정보를 확인하고 관리합니다.',
          mine.isEmpty
              ? _empty('가입한 $title 상품이 없습니다.')
              : _responsiveCards(
            mine.map(_ownedCard).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _panel(
          '$title 상품',
          '상품 조건을 확인한 뒤 생활계좌 자금으로 가입할 수 있습니다.',
          products.isEmpty
              ? _empty(
            '현재 가입 가능한 $title 상품이 없습니다.',
          )
              : _responsiveCards(
            products.map(_productCard).toList(),
          ),
        ),
      ],
    );
  }

  Widget _productCard(BankProductModel item) {
    return _smallCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.bankName.isEmpty
                ? '은행'
                : item.bankName,
            style: const TextStyle(
              fontSize: 12,
              color: _muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '연 ${item.annualRate.toStringAsFixed(2)}%',
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '기간 ${_termLabel(item.termDays)} · '
                '최소 ${_money(item.minAmount)}',
            style: const TextStyle(
              fontSize: 12,
              color: _muted,
            ),
          ),
          if (item.isSavings &&
              item.installmentCount != null)
            Text(
              '총 ${item.installmentCount}회 납입',
              style: const TextStyle(
                fontSize: 12,
                color: _muted,
              ),
            ),
          if (item.description?.trim().isNotEmpty ==
              true) ...[
            const SizedBox(height: 8),
            Text(
              item.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: _muted,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _working
                ? null
                : () => _joinProduct(item),
            child: const Text('가입하기'),
          ),
        ],
      ),
    );
  }

  Widget _ownedCard(
      UserBankAccountModel item,
      ) {
    final realNow = DateTime.now().toUtc();
    final gameNow = _gameClock?.at(realNow);
    final matured = item.maturedAt(realNow: realNow, gameNow: gameNow);
    final canClaim = matured && (!item.usesGameTime || item.installmentsComplete);

    return _smallCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productNameSnapshot,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '납입원금 ${_money(item.principalAmount)}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '연 ${item.annualRateSnapshot.toStringAsFixed(2)}%',
            style: const TextStyle(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 8),
          Text(
            '만기 예정 · 한국시간\n${_productDeadline(item, item.maturityAt)}',
            style: const TextStyle(fontSize: 14, color: _ink, height: 1.5),
          ),
          const SizedBox(height: 5),
          Text(
            '예상 만기 수령액 '
                '${_money(item.expectedMaturityAmount)}',
            style: const TextStyle(
              fontSize: 14,
              color: _muted,
            ),
          ),
          if (item.isSavings) ...[
            const SizedBox(height: 5),
            Text(
              '납입 ${item.paidInstallments}/'
                  '${item.totalInstallments ?? '-'}회 · '
                  '다음 납입 예정 · 한국시간\n'
                  '${item.nextPaymentDueAt == null ? '-' : _productDeadline(item, item.nextPaymentDueAt!)}',
              style: const TextStyle(
                fontSize: 14,
                color: _muted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.isSavings &&
                  (!matured || item.usesGameTime) &&
                  item.remainingInstallments > 0)
                OutlinedButton(
                  onPressed: _working || (item.usesGameTime && gameNow == null)
                      ? null
                      : () => _payInstallment(item),
                  child: const Text('회차 납입'),
                ),
              if (canClaim)
                FilledButton(
                  onPressed: _working
                      ? null
                      : () => _claim(item),
                  child: const Text('만기 수령'),
                ),
              OutlinedButton(
                onPressed: _working
                    ? null
                    : () => _cancel(item),
                child: const Text('중도해지'),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _loanTab() {
    return LoanCatalogSection(
      onChanged: () {
        _loadData(showLoading: false);
      },
    );
  }

  Future<void> _refreshBankActivity() async {
    if (_refreshingActivity || !mounted) return;
    _refreshingActivity = true;
    try {
      final results = await Future.wait([
        _assetRepository.fetchUserAssetAccounts(),
        _assetRepository.fetchBankAccountTransactions(),
      ]);
      if (!mounted) return;
      setState(() {
        _accounts = results[0].where((a) => const ['bank', 'stock', 'coin'].contains(a['account_type'])).toList();
        _transactions = results[1];
        _historyError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _historyError = '최신 거래내역을 불러오지 못했습니다. 다시 조회해 주세요.');
    } finally {
      _refreshingActivity = false;
    }
  }

  List<Map<String, dynamic>> get _filteredHistory {
    if (_historyPeriod == 'recent') {
      return _transactions.take(30).toList();
    }

    if (_historyPeriod == 'all') {
      return _transactions;
    }

    final days = _historyPeriod == '1m'
        ? 30
        : _historyPeriod == '3m'
        ? 90
        : 365;

    final cutoff =
    DateTime.now().subtract(Duration(days: days));

    return _transactions.where((row) {
      final date = DateTime.tryParse(
        row['created_at']?.toString() ?? '',
      );

      return date != null &&
          !date.isBefore(cutoff);
    }).toList();
  }

  Widget _historyTab() {
    const periods = [
      ('recent', '최근'),
      ('1m', '1개월'),
      ('3m', '3개월'),
      ('1y', '1년'),
      ('all', '전체'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          '조회 기간',
          '최근 최대 300건의 은행·계좌 자금 이동 기록을 조회합니다.',
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final period in periods) ...[
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _historyPeriod = period.$1;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                      _historyPeriod == period.$1
                          ? _ink
                          : Colors.white,
                      foregroundColor:
                      _historyPeriod == period.$1
                          ? Colors.white
                          : _ink,
                      side: const BorderSide(
                        color: _border,
                      ),
                    ),
                    child: Text(period.$2),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_historyError != null) ...[
          Text(_historyError!, style: const TextStyle(fontSize: 14, color: _muted)),
          TextButton.icon(onPressed: _refreshBankActivity, icon: const Icon(Icons.refresh), label: const Text('거래내역 다시 조회')),
          const SizedBox(height: 12),
        ],
        AssetTransactionListWidget(
          title: '은행 거래내역',
          transactions: _filteredHistory,
        ),
      ],
    );
  }
}
