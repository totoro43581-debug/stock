import 'package:stock/core/game_time/game_time_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/asset_account/repository/asset_account_repository.dart';
import 'package:stock/feature/bank/model/user_bank_account_model.dart';
import 'package:stock/feature/bank/repository/bank_repository.dart';
import 'package:stock/feature/coin/model/coin_holding_model.dart';
import 'package:stock/feature/coin/repository/coin_repository.dart';
import 'package:stock/feature/stock/model/stock_holding_model.dart';
import 'package:stock/feature/stock/repository/stock_trade_repository.dart';

class AssetAccountScreen extends StatefulWidget {
  const AssetAccountScreen({super.key});

  @override
  State<AssetAccountScreen> createState() => _AssetAccountScreenState();
}

class _AssetAccountScreenState extends State<AssetAccountScreen> {
  final _client = Supabase.instance.client;
  final _assetRepo = AssetAccountRepository();
  final _stockRepo = StockTradeRepository();
  final _coinRepo = CoinRepository();
  final _bankRepo = BankRepository();
  final _money = NumberFormat('#,##0');
  final _decimal = NumberFormat('#,##0.########');

  bool _loading = true;
  bool _showAllTrades = false;
  String? _error;
  List<Map<String, dynamic>> _accounts = [];
  List<StockHoldingModel> _stocks = [];
  List<CoinHoldingModel> _coins = [];
  List<UserBankAccountModel> _bankProducts = [];
  Map<String, dynamic> _loanLiabilities = {};
  GameClockMapping? _clockMapping;
  List<_InvestmentTrade> _trades = [];
  Map<String, double> _stockPrices = {};
  Map<String, double> _coinPrices = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _won(double amount) => '${_money.format(amount.round())}원';

  String _quantity(double amount) => _decimal.format(amount);

  double _cash(String type) {
    for (final account in _accounts) {
      if (account['account_type'] == type) {
        return _number(account['cash_balance']);
      }
    }
    return 0;
  }

  Future<Map<String, double>> _fetchPrices(
      String table,
      List<String> codes,
      ) async {
    if (codes.isEmpty) return {};
    final rows = await _client
        .from(table)
        .select('code,current_price')
        .inFilter('code', codes);
    final prices = <String, double>{};
    for (final row in rows) {
      final code = row['code']?.toString();
      if (code != null && row['current_price'] != null) {
        prices[code] = _number(row['current_price']);
      }
    }
    return prices;
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다.');

      final accounts = await _assetRepo.fetchUserAssetAccounts();
      final stocks = await _stockRepo.fetchHoldings(user.id);
      final coins = await _coinRepo.fetchMyCoinHoldings();
      final bankProducts = await _bankRepo.fetchMyActiveBankAccounts();
      final clockMapping = await _bankRepo.fetchClockMapping();

      final loanResponse = await _client.rpc('get_my_loan_liabilities');

      final loanLiabilities = loanResponse is Map
          ? Map<String, dynamic>.from(loanResponse)
          : <String, dynamic>{};

      final stockHistory = await _stockRepo.fetchTradeHistory(user.id);
      final coinHistory = await _coinRepo.fetchMyCoinTradeHistory();

      final stockPrices = await _fetchPrices(
        'stock_item',
        stocks.map((e) => e.stockCode).toSet().toList(),
      );
      final coinPrices = await _fetchPrices(
        'coin_item',
        coins.map((e) => e.coinCode).toSet().toList(),
      );

      final trades = <_InvestmentTrade>[
        for (final item in stockHistory)
          _InvestmentTrade(
            market: '주식',
            name: item.stockName,
            action: item.tradeType,
            quantity: item.quantity.toDouble(),
            price: item.price,
            amount: item.totalAmount,
            at: item.createdAt,
          ),
        for (final item in coinHistory)
          _InvestmentTrade(
            market: '코인',
            name: item.coinName,
            action: item.tradeType,
            quantity: item.quantity,
            price: item.tradePrice,
            amount: item.totalAmount,
            at: item.createdAt,
          ),
      ]..sort((a, b) =>
          (b.at ?? DateTime(1970)).compareTo(a.at ?? DateTime(1970)));

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _stocks = stocks;
        _coins = coins;
        _bankProducts = bankProducts;
        _clockMapping = clockMapping;
        _loanLiabilities = loanLiabilities;
        _stockPrices = stockPrices;
        _coinPrices = coinPrices;
        _trades = trades;
        _showAllTrades = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  bool get _pricesComplete =>
      _stocks.every((e) => _stockPrices.containsKey(e.stockCode)) &&
          _coins.every((e) => _coinPrices.containsKey(e.coinCode));

  double get _stockValue => _stocks.fold(0.0, (sum, e) =>
  sum + (_stockPrices[e.stockCode] ?? 0) * e.quantity);

  double get _coinValue => _coins.fold(0.0, (sum, e) =>
  sum + (_coinPrices[e.coinCode] ?? 0) * e.quantity);

  double get _stockCost => _stocks.fold(0.0, (sum, e) =>
  sum + e.averagePrice * e.quantity);

  double get _coinCost => _coins.fold(0.0, (sum, e) =>
  sum + e.averagePrice * e.quantity);

  double get _bankPrincipal => _bankProducts.fold(0.0, (sum, e) =>
  sum + e.principalAmount);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: _error != null
                ? _panel(
              title: '자산 정보를 불러오지 못했습니다',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _load,
                    child: const Text('다시 조회'),
                  ),
                ],
              ),
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 16),
                _summary(),
                const SizedBox(height: 16),
                _stockSection(),
                const SizedBox(height: 16),
                _coinSection(),
                const SizedBox(height: 16),
                _bankSection(),
                const SizedBox(height: 16),
                _tradeSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return _panel(
      title: '자산현황',
      subtitle: '현재 보유한 투자자산과 매매내역을 한눈에 확인합니다.',
      trailing: IconButton(
        onPressed: _load,
        tooltip: '새로고침',
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: const Text(
        '금융자산은 계좌 현금 + 보유 투자상품 평가액 + 예·적금 납입원금으로 계산합니다. '
            '부동산은 아직 미연동이며, 금융 순자산은 확인된 금융자산에서 '
            '대출 원금과 발생이자를 차감합니다.',
        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.5),
      ),
    );
  }

  Widget _summary() {
    final cash = _cash('bank') + _cash('stock') + _cash('coin');
    final total = cash + _stockValue + _coinValue + _bankPrincipal;
    final gain = (_stockValue - _stockCost) + (_coinValue - _coinCost);

    final debtPrincipal = _number(_loanLiabilities['principal']);
    final debtInterest = _number(_loanLiabilities['accrued_interest']);
    final totalDebt = _number(_loanLiabilities['total_debt']);

    final netFinancialAssets = total - totalDebt;

    final cards = <Widget>[
      _stat('확인된 금융자산', _pricesComplete ? _won(total) : '시세 미확인',
          '부동산·부채 미포함', Icons.account_balance_wallet_outlined),
      _stat('계좌 보유현금', _won(cash),
          '생활 ${_won(_cash('bank'))} · 주식 ${_won(_cash('stock'))} · 코인 ${_won(_cash('coin'))}',
          Icons.payments_outlined),
      _stat('주식 평가금액',
          _stocks.every((e) => _stockPrices.containsKey(e.stockCode))
              ? _won(_stockValue) : '시세 미확인',
          '보유 종목 ${_stocks.length}개', Icons.show_chart_rounded),
      _stat('코인 평가금액',
          _coins.every((e) => _coinPrices.containsKey(e.coinCode))
              ? _won(_coinValue) : '시세 미확인',
          '보유 코인 ${_coins.length}개', Icons.currency_bitcoin_rounded),
      _stat('예·적금 납입원금', _won(_bankPrincipal),
          '가입 상품 ${_bankProducts.length}개 · 예상 이자 제외',
          Icons.savings_outlined),
      _stat('보유자산 평가손익', _pricesComplete ? _signedWon(gain) : '시세 미확인',
          '주식·코인 미실현 손익만', Icons.trending_up_rounded,
          valueColor: gain < 0 ? const Color(0xFF2563EB) :
          gain > 0 ? const Color(0xFFDC2626) : null),
      _stat('부동산 자산', '미연동', '매매 기능 개발 후 반영', Icons.home_outlined),

      _stat(
        '대출·부채',
        _won(totalDebt),
        '미상환 원금 ${_won(debtPrincipal)} · 발생이자 ${_won(debtInterest)}',
        Icons.receipt_long_outlined,
      ),
      _stat(
        '금융 순자산',
        _pricesComplete ? _won(netFinancialAssets) : '시세 미확인',
        '금융자산 − 대출 원금 − 발생이자 · 부동산 제외',
        Icons.account_balance_outlined,
      ),

    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1040 ? 4 : width >= 600 ? 2 : 1;
        final cardWidth = (width - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final card in cards) SizedBox(width: cardWidth, child: card)],
        );
      },
    );
  }

  String _signedWon(double value) =>
      '${value > 0 ? '+' : ''}${_won(value)}';

  Widget _stat(String title, String amount, String description, IconData icon,
      {Color? valueColor}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 136),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700))),
            Icon(icon, size: 19, color: const Color(0xFF6B7280)),
          ]),
          const SizedBox(height: 12),
          Text(amount, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900,
                  color: valueColor ?? const Color(0xFF111827))),
          const SizedBox(height: 8),
          Text(description, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _panel({required String title, required Widget child,
    String? subtitle, Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827))),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(subtitle, style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280))),
                ],
              ],
            )),
            ?trailing,
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _empty(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
    alignment: Alignment.center,
    decoration: BoxDecoration(color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12)),
    child: Text(message, style: const TextStyle(color: Color(0xFF6B7280))),
  );

  Widget _holdingRow({required String name, required String subtitle,
    required double quantity, required double average,
    required double? current, required bool isCoin}) {
    final cost = quantity * average;
    final value = current == null ? null : quantity * current;
    final gain = value == null ? null : value - cost;
    final percent = gain == null || cost <= 0 ? null : gain / cost * 100;
    final gainColor = (gain ?? 0) < 0 ? const Color(0xFF2563EB) :
    (gain ?? 0) > 0 ? const Color(0xFFDC2626) : const Color(0xFF111827);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name.isEmpty ? subtitle : name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: Color(0xFF111827))),
        const SizedBox(height: 10),
        Wrap(spacing: 22, runSpacing: 10, children: [
          _metric('보유수량', '${_quantity(quantity)}${isCoin ? '' : '주'}'),
          _metric('평균매수가', _won(average)),
          _metric('현재가', current == null ? '시세 없음' : _won(current)),
          _metric('평가금액', value == null ? '미집계' : _won(value)),
          _metric('평가손익', gain == null ? '미집계' :
          '${_signedWon(gain)}${percent == null ? '' : ' (${percent.toStringAsFixed(2)}%)'}',
              color: gainColor),
        ]),
      ]),
    );
  }

  Widget _metric(String label, String value, {Color? color}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color ?? const Color(0xFF111827))),
      ]);

  Widget _stockSection() => _panel(
    title: '보유 주식',
    subtitle: '현재 보유수량과 평균매수가를 기준으로 평가합니다.',
    child: _stocks.isEmpty ? _empty('보유한 주식이 없습니다.') : Column(children: [
      for (var i = 0; i < _stocks.length; i++) ...[
        _holdingRow(name: _stocks[i].stockName,
            subtitle: _stocks[i].stockCode,
            quantity: _stocks[i].quantity.toDouble(),
            average: _stocks[i].averagePrice,
            current: _stockPrices[_stocks[i].stockCode], isCoin: false),
        if (i != _stocks.length - 1) const SizedBox(height: 9),
      ],
    ]),
  );

  Widget _coinSection() => _panel(
    title: '보유 코인',
    subtitle: '현재 보유수량과 평균매수가를 기준으로 평가합니다.',
    child: _coins.isEmpty ? _empty('보유한 코인이 없습니다.') : Column(children: [
      for (var i = 0; i < _coins.length; i++) ...[
        _holdingRow(name: _coins[i].coinName,
            subtitle: _coins[i].coinCode,
            quantity: _coins[i].quantity, average: _coins[i].averagePrice,
            current: _coinPrices[_coins[i].coinCode], isCoin: true),
        if (i != _coins.length - 1) const SizedBox(height: 9),
      ],
    ]),
  );

  Widget _bankSection() => _panel(
    title: '보유 예·적금',
    subtitle: '현재 납입원금만 금융자산에 합산하며 만기 예상이자는 별도 표시합니다.',
    child: _bankProducts.isEmpty
        ? _empty('가입 중인 예금·적금 상품이 없습니다.')
        : Column(children: [
      for (var i = 0; i < _bankProducts.length; i++) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_bankProducts[i].isDeposit ? '예금' : '적금'} · '
                    '${_bankProducts[i].productNameSnapshot}',
                    style: const TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(spacing: 22, runSpacing: 10, children: [
                  _metric('납입원금', _won(_bankProducts[i].principalAmount)),
                  _metric('연이율',
                      '${_bankProducts[i].annualRateSnapshot.toStringAsFixed(2)}%'),
                  _metric('만기 예정 · 한국시간', realDeadlineLabel(
                      _bankProducts[i].usesGameTime
                          ? _clockMapping?.realTimeForGameTime(_bankProducts[i].maturityAt)
                          : _bankProducts[i].maturityAt.toUtc(),
                      showRemaining: false)),
                  _metric('만기 예상금액',
                      _won(_bankProducts[i].expectedMaturityAmount)),
                ]),
              ]),
        ),
        if (i != _bankProducts.length - 1) const SizedBox(height: 9),
      ],
    ]),
  );

  Widget _tradeSection() {
    final shown = _showAllTrades ? _trades : _trades.take(5).toList();
    return _panel(
      title: '최근 투자 매매내역',
      subtitle: '계좌이체 내역이 아닌 실제 주식·코인 매매 기록입니다.',
      child: _trades.isEmpty
          ? _empty('주식·코인 매매내역이 없습니다.')
          : Column(children: [
        for (var i = 0; i < shown.length; i++) ...[
          _tradeRow(shown[i]),
          if (i != shown.length - 1) const SizedBox(height: 8),
        ],
        if (_trades.length > 5) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() {
              _showAllTrades = !_showAllTrades;
            }),
            style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF111827),
                side: const BorderSide(color: Color(0xFFD1D5DB))),
            child: Text(_showAllTrades
                ? '접기' : '더보기 (${_trades.length - 5}건)'),
          ),
        ],
      ]),
    );
  }

  Widget _tradeRow(_InvestmentTrade trade) {
    final isBuy = trade.action == 'buy';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: isBuy
                ? const Color(0xFFFEE2E2) : const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(999)),
            child: Text(isBuy ? '매수' : '매도',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: isBuy ? const Color(0xFFDC2626) :
                    const Color(0xFF2563EB))),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text('${trade.market} · ${trade.name}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800))),
          Text(_won(trade.amount),
              style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 7),
        Text('${_quantity(trade.quantity)}${trade.market == '주식' ? '주' : '개'} · 체결가 ${_won(trade.price)}'
            '${trade.at == null ? '' : ' · ${DateFormat('MM.dd HH:mm').format(trade.at!.toLocal())}'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      ]),
    );
  }
}

class _InvestmentTrade {
  final String market;
  final String name;
  final String action;
  final double quantity;
  final double price;
  final double amount;
  final DateTime? at;

  const _InvestmentTrade({
    required this.market,
    required this.name,
    required this.action,
    required this.quantity,
    required this.price,
    required this.amount,
    required this.at,
  });
}
