import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:stock/feature/quest/service/daily_quest_service.dart';
import 'package:stock/feature/stock/model/stock_candle_model.dart';
import 'package:stock/feature/stock/model/stock_holding_model.dart';
import 'package:stock/feature/stock/model/stock_trade_history_model.dart';
import 'package:stock/feature/stock/repository/stock_price_repository.dart';
import 'package:stock/feature/stock/repository/stock_repository.dart';
import 'package:stock/feature/stock/repository/stock_trade_repository.dart';
import 'package:stock/feature/stock/view/stock_register_screen.dart';
import 'package:stock/feature/stock/view/widget/stock_price_chart.dart';
import 'package:stock/feature/wallet/model/wallet_model.dart';
import 'package:stock/feature/wallet/repository/wallet_repository.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final StockRepository _stockRepository = StockRepository();
  final StockTradeRepository _stockTradeRepository = StockTradeRepository();
  final StockPriceRepository _stockPriceRepository = StockPriceRepository();
  final WalletRepository _walletRepository = WalletRepository();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController =
  TextEditingController(text: '1');

  Timer? _realtimePriceTimer;

  bool _isRealtimeUpdating = false;
  bool _isWalletLoading = false;
  bool _isTrading = false;
  bool _showOnlyOwned = false;
  bool _isBuyOrder = true;
  bool _isChartLoading = false;

  DateTime? _lastRealtimeUpdatedAt;

  WalletModel? _wallet;

  List<_StockItem> _marketItems = [];
  List<StockHoldingModel> _holdingItems = [];
  List<StockTradeHistoryModel> _tradeHistoryItems = [];
  List<StockCandleModel> _selectedStockPrices = [];

  _StockItem? _selectedMarketItem;
  double? _selectedOrderPrice;

  String _selectedCategoryTab = '전체';
  String _selectedMarketFilter = '전체';
  String _selectedSort = '이름';

  int _tradeHistoryPage = 0;
  static const int _tradeHistoryPageSize = 5;

  SupabaseClient get _supabase => Supabase.instance.client;
  Session? get _session => _supabase.auth.currentSession;
  User? get _user => _supabase.auth.currentUser;

  bool get _isLoggedIn => _session != null && _user != null;

  static const double _pageMaxWidth = 1480;
  static const double _gap = 14;
  static const double _radius = 18;

  @override
  void initState() {
    super.initState();

    _completeOpenMarketQuest();
    _loadInitialData();
    _startRealtimePriceUpdate();

    _quantityController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _realtimePriceTimer?.cancel();
    super.dispose();
  }

  Future<void> _completeOpenMarketQuest() async {
    try {
      await DailyQuestService.instance.completeOpenMarketQuest();
    } catch (_) {}
  }

  Future<void> _loadInitialData() async {
    await _loadMarketItems();
    await _loadWallet();
    await _loadHoldings();
    await _loadTradeHistory();
  }

  void _startRealtimePriceUpdate() {
    _realtimePriceTimer?.cancel();

    _realtimePriceTimer = Timer.periodic(
      const Duration(minutes: 5),
          (_) async {
        if (!mounted || _isRealtimeUpdating) return;

        try {
          _isRealtimeUpdating = true;

          await _stockPriceRepository.simulateStockPrices();

          if (mounted) {
            setState(() {
              _lastRealtimeUpdatedAt = DateTime.now();
            });
          }

          await _loadMarketItems();

          final selectedItem = _selectedMarketItem;
          if (selectedItem != null) {
            await _loadStockChart(selectedItem.id, selectedItem.name);
          }
        } catch (e) {
          debugPrint('실시간 가격 갱신 실패: $e');
        } finally {
          _isRealtimeUpdating = false;
        }
      },
    );
  }

  Future<void> _loadMarketItems() async {
    try {
      final rows = await _stockRepository.fetchActiveStocks();

      final items = rows.map((row) {
        return _StockItem(
          id: row['id'].toString(),
          code: (row['code'] ?? '').toString(),
          name: (row['name'] ?? '').toString(),
          market: _mapMarketLabel((row['market'] ?? '').toString()),
          currentPrice: ((row['current_price'] ?? 0) as num).toDouble(),
          changeRate: ((row['change_rate'] ?? 0) as num).toDouble(),
          description: (row['market'] ?? '').toString().isEmpty
              ? ''
              : '${(row['market'] ?? '').toString()} 종목',
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _marketItems = items;

        if (_selectedMarketItem == null && items.isNotEmpty) {
          _selectedMarketItem = items.first;
          _selectedOrderPrice = null;

          Future.microtask(() {
            _loadStockChart(items.first.id, items.first.name);
          });
        } else if (_selectedMarketItem != null) {
          final selectedCode = _selectedMarketItem!.code;
          try {
            _selectedMarketItem =
                items.firstWhere((item) => item.code == selectedCode);
          } catch (_) {}
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('종목 데이터를 불러오지 못했습니다: $e');
    }
  }

  Future<void> _loadWallet() async {
    if (!_isLoggedIn || _user == null) {
      if (!mounted) return;
      setState(() {
        _wallet = null;
        _isWalletLoading = false;
      });
      return;
    }

    try {
      if (!mounted) return;
      setState(() {
        _isWalletLoading = true;
      });

      final wallet = await _walletRepository.ensureWallet(_user!.id);

      if (!mounted) return;
      setState(() {
        _wallet = wallet;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('지갑 정보를 불러오지 못했습니다: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isWalletLoading = false;
      });
    }
  }

  Future<void> _loadHoldings() async {
    if (!_isLoggedIn || _user == null) {
      if (!mounted) return;
      setState(() {
        _holdingItems = [];
      });
      return;
    }

    try {
      final holdings = await _stockTradeRepository.fetchHoldings(_user!.id);

      if (!mounted) return;
      setState(() {
        _holdingItems = holdings;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('보유종목을 불러오지 못했습니다: $e');
    }
  }

  Future<void> _loadTradeHistory() async {
    if (!_isLoggedIn || _user == null) {
      if (!mounted) return;
      setState(() {
        _tradeHistoryItems = [];
        _tradeHistoryPage = 0;
      });
      return;
    }

    try {
      final histories = await _stockTradeRepository.fetchTradeHistory(_user!.id);

      if (!mounted) return;
      setState(() {
        _tradeHistoryItems = histories;
        _tradeHistoryPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('거래내역을 불러오지 못했습니다: $e');
    }
  }

  Future<void> _loadStockChart(String stockId, String stockName) async {
    setState(() {
      _isChartLoading = true;
    });

    try {
      final prices = await _stockPriceRepository.fetchCandlesByStockId(stockId);

      if (!mounted) return;
      setState(() {
        _selectedStockPrices = prices;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedStockPrices = [];
      });
      _showSnackBar('차트 데이터를 불러오지 못했습니다: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isChartLoading = false;
      });
    }
  }

  Future<void> _reloadAfterTrade() async {
    await _loadWallet();
    await _loadHoldings();
    await _loadTradeHistory();
  }

  String _mapMarketLabel(String market) {
    switch (market.toUpperCase()) {
      case 'KOSPI':
      case 'KOSDAQ':
        return '국내';
      case 'NASDAQ':
      case 'NYSE':
      case 'AMEX':
        return '해외';
      default:
        return market;
    }
  }

  double get _cash => (_wallet?.cashBalance ?? 0).toDouble();

  double get _orderPrice {
    return _selectedOrderPrice ?? _selectedMarketItem?.currentPrice ?? 0;
  }

  double get _totalStockValue {
    double total = 0;

    for (final holding in _holdingItems) {
      final stock = _findMarketItemByCode(holding.stockCode);
      if (stock == null) continue;

      total += stock.currentPrice * holding.quantity;
    }

    return total;
  }

  double get _totalAsset => _cash + _totalStockValue;

  double get _totalProfitAmount {
    double total = 0;

    for (final holding in _holdingItems) {
      final stock = _findMarketItemByCode(holding.stockCode);
      if (stock == null) continue;

      total += (stock.currentPrice - holding.averagePrice) * holding.quantity;
    }

    return total;
  }

  double get _totalProfitRate {
    double totalBuyAmount = 0;

    for (final holding in _holdingItems) {
      totalBuyAmount += holding.averagePrice * holding.quantity;
    }

    if (totalBuyAmount <= 0) return 0;

    return (_totalProfitAmount / totalBuyAmount) * 100;
  }

  _StockItem? _findMarketItemByCode(String code) {
    try {
      return _marketItems.firstWhere((item) => item.code == code);
    } catch (_) {
      return null;
    }
  }

  StockHoldingModel? _findHoldingByCode(String code) {
    try {
      return _holdingItems.firstWhere((item) => item.stockCode == code);
    } catch (_) {
      return null;
    }
  }

  List<_StockItem> get _filteredItems {
    List<_StockItem> result = List.of(_marketItems);

    if (_selectedCategoryTab == '국내주식') {
      result = result.where((item) => item.market == '국내').toList();
    } else if (_selectedCategoryTab == '해외주식') {
      result = result.where((item) => item.market == '해외').toList();
    } else if (_selectedCategoryTab == 'ETF') {
      result = result
          .where(
            (item) =>
        item.name.toUpperCase().contains('ETF') ||
            item.description.toUpperCase().contains('ETF'),
      )
          .toList();
    } else if (_selectedCategoryTab == '테마') {
      result = result
          .where(
            (item) =>
        item.description.contains('테마') ||
            item.description.contains('AI') ||
            item.description.contains('반도체') ||
            item.description.contains('2차전지'),
      )
          .toList();
    }

    if (_selectedMarketFilter != '전체') {
      result =
          result.where((item) => item.market == _selectedMarketFilter).toList();
    }

    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isNotEmpty) {
      result = result.where((item) {
        return item.name.toLowerCase().contains(keyword) ||
            item.code.toLowerCase().contains(keyword);
      }).toList();
    }

    if (_showOnlyOwned) {
      result = result.where((item) {
        return _holdingItems.any((holding) => holding.stockCode == item.code);
      }).toList();
    }

    switch (_selectedSort) {
      case '등락률':
        result.sort((a, b) => b.changeRate.compareTo(a.changeRate));
        break;
      case '현재가':
        result.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
        break;
      case '이름':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
    }

    return result;
  }

  List<double> _buildAskPrices(double currentPrice) {
    return List.generate(8, (index) {
      return currentPrice + ((8 - index) * 100);
    });
  }

  List<double> _buildBidPrices(double currentPrice) {
    return List.generate(8, (index) {
      return currentPrice - ((index + 1) * 100);
    });
  }

  Color _changeColor(double value) {
    if (value > 0) return const Color(0xFFDC2626);
    if (value < 0) return const Color(0xFF2563EB);
    return const Color(0xFF6B7280);
  }

  String _formatPrice(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  String _formatSignedPrice(num value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${_formatPrice(value)}';
  }

  String _formatSignedPercent(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}%';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';

    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$month-$day $hour:$minute';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _increaseQuantity() {
    final current = int.tryParse(_quantityController.text.trim()) ?? 1;
    _quantityController.text = (current + 1).toString();
  }

  void _decreaseQuantity() {
    final current = int.tryParse(_quantityController.text.trim()) ?? 1;

    if (current <= 1) {
      _quantityController.text = '1';
      return;
    }

    _quantityController.text = (current - 1).toString();
  }

  Future<void> _handleBuy() async {
    if (!_isLoggedIn || _user == null) {
      _showSnackBar('로그인 후 이용 가능합니다.');
      return;
    }

    if (_selectedMarketItem == null) {
      _showSnackBar('매수할 종목을 선택해주세요.');
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;

    if (quantity <= 0) {
      _showSnackBar('수량은 1주 이상 입력해주세요.');
      return;
    }

    if (_isTrading) return;

    try {
      setState(() {
        _isTrading = true;
      });

      final item = _selectedMarketItem!;

      await _stockTradeRepository.buyStock(
        userId: _user!.id,
        stockCode: item.code,
        stockName: item.name,
        price: _orderPrice,
        quantity: quantity,
      );

      await _reloadAfterTrade();

      if (!mounted) return;
      _showSnackBar('매수 완료: ${item.name} ${quantity}주');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (!mounted) return;
      setState(() {
        _isTrading = false;
      });
    }
  }

  Future<void> _handleSell() async {
    if (!_isLoggedIn || _user == null) {
      _showSnackBar('로그인 후 이용 가능합니다.');
      return;
    }

    if (_selectedMarketItem == null) {
      _showSnackBar('매도할 종목을 선택해주세요.');
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;

    if (quantity <= 0) {
      _showSnackBar('수량은 1주 이상 입력해주세요.');
      return;
    }

    if (_isTrading) return;

    try {
      setState(() {
        _isTrading = true;
      });

      final item = _selectedMarketItem!;

      await _stockTradeRepository.sellStock(
        userId: _user!.id,
        stockCode: item.code,
        stockName: item.name,
        price: _orderPrice,
        quantity: quantity,
      );

      await _reloadAfterTrade();

      if (!mounted) return;
      _showSnackBar('매도 완료: ${item.name} ${quantity}주');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (!mounted) return;
      setState(() {
        _isTrading = false;
      });
    }
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_radius),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x06000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: _gap),
                _buildSummarySection(),
                const SizedBox(height: _gap),
                _buildTradingLayout(filteredItems),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final item = _selectedMarketItem;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: item == null
                ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '주식',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '종목을 선택하면 차트, 호가, 주문창이 표시됩니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ],
            )
                : Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    item.name.characters.first,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.code} · ${item.market}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 28),
                Text(
                  '₩ ${_formatPrice(item.currentPrice)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatSignedPercent(item.changeRate),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _changeColor(item.changeRate),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StockRegisterScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                '종목 등록',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final cards = [
      _buildSummaryCard(
        title: '총 자산',
        value: '₩ ${_formatPrice(_totalAsset)}',
        subValue: '현금 + 주식 평가금',
        valueColor: const Color(0xFF111827),
      ),
      _buildSummaryCard(
        title: '보유 현금',
        value: '₩ ${_formatPrice(_cash)}',
        subValue: _isWalletLoading ? '지갑 불러오는 중' : 'wallet.cash_balance',
        valueColor: const Color(0xFF111827),
      ),
      _buildSummaryCard(
        title: '주식 평가금',
        value: '₩ ${_formatPrice(_totalStockValue)}',
        subValue: '보유 종목 현재가 기준',
        valueColor: const Color(0xFF111827),
      ),
      _buildSummaryCard(
        title: '총 손익',
        value: '${_formatSignedPrice(_totalProfitAmount)}원',
        subValue: _formatSignedPercent(_totalProfitRate),
        valueColor: _changeColor(_totalProfitAmount),
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subValue,
    required Color valueColor,
  }) {
    return Container(
      height: 124,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              height: 1.0,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradingLayout(List<_StockItem> filteredItems) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: _buildChartSection(),
            ),
            const SizedBox(width: _gap),
            Expanded(
              flex: 3,
              child: _buildMarketListSection(filteredItems),
            ),
          ],
        ),
        const SizedBox(height: _gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: _buildBottomTradingArea(),
            ),
            const SizedBox(width: _gap),
            Expanded(
              flex: 3,
              child: _buildTradePanelSection(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartSection() {
    final item = _selectedMarketItem;

    return Container(
      height: 520,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item == null ? '차트' : '${item.name} 차트',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _buildRealtimeBadge(),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isChartLoading
                ? const Center(child: CircularProgressIndicator())
                : StockPriceChart(
              prices: _selectedStockPrices,
              currentPrice: item?.currentPrice ?? 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeBadge() {
    final timeText = _lastRealtimeUpdatedAt == null
        ? '대기 중'
        : '${_lastRealtimeUpdatedAt!.hour.toString().padLeft(2, '0')}:'
        '${_lastRealtimeUpdatedAt!.minute.toString().padLeft(2, '0')}:'
        '${_lastRealtimeUpdatedAt!.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '실시간 · 5분 갱신 · $timeText',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketListSection(List<_StockItem> items) {
    return Container(
      height: 520,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '종목 리스트',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          _buildFilterCompact(),
          const SizedBox(height: 10),
          Expanded(
            child: items.isEmpty
                ? const Center(
              child: Text(
                '조건에 맞는 종목이 없습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            )
                : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) {
                return const Divider(
                  height: 1,
                  color: Color(0xFFF1F5F9),
                );
              },
              itemBuilder: (context, index) {
                return _buildMarketListRow(items[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCompact() {
    return Column(
      children: [
        SizedBox(
          height: 38,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: '종목명 / 코드 검색',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSmallSelect(
                value: _selectedMarketFilter,
                items: const ['전체', '국내', '해외'],
                onChanged: (value) {
                  setState(() {
                    _selectedMarketFilter = value!;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallSelect(
                value: _selectedSort,
                items: const ['이름', '현재가', '등락률'],
                onChanged: (value) {
                  setState(() {
                    _selectedSort = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallSelect({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map(
                (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
              .toList(),
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketListRow(_StockItem item) {
    final selected = _selectedMarketItem?.code == item.code;
    final holding = _findHoldingByCode(item.code);
    final holdingQty = holding?.quantity ?? 0;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMarketItem = item;
          _selectedOrderPrice = null;
        });

        _loadStockChart(item.id, item.name);
      },
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _changeColor(item.changeRate),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.code,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₩ ${_formatPrice(item.currentPrice)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatSignedPercent(item.changeRate)} · ${holdingQty}주',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _changeColor(item.changeRate),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTradingArea() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 45,
          child: _buildOrderBookSection(),
        ),
        const SizedBox(width: _gap),
        Expanded(
          flex: 55,
          child: _buildTradeHistorySection(),
        ),
      ],
    );
  }

  Widget _buildOrderBookSection() {
    final item = _selectedMarketItem;

    if (item == null) {
      return Container(
        height: 420,
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: const Center(
          child: Text(
            '호가를 표시할 종목을 선택해주세요.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    final askPrices = _buildAskPrices(item.currentPrice);
    final bidPrices = _buildBidPrices(item.currentPrice);

    return Container(
      height: 420,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '호가',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              children: [
                for (final price in askPrices)
                  Expanded(
                    child: _buildOrderBookRow(
                      label: '매도',
                      price: price,
                      isAsk: true,
                    ),
                  ),
                Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                      top: BorderSide(color: Color(0xFFE5E7EB)),
                      bottom: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Text(
                    '현재가 ₩ ${_formatPrice(item.currentPrice)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                for (final price in bidPrices)
                  Expanded(
                    child: _buildOrderBookRow(
                      label: '매수',
                      price: price,
                      isAsk: false,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderBookRow({
    required String label,
    required double price,
    required bool isAsk,
  }) {
    final selected = _selectedOrderPrice?.round() == price.round();

    final fakeQty = (price.round().abs() % 17) + 1;
    final color = isAsk ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedOrderPrice = price;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFF7ED)
              : isAsk
              ? const Color(0xFFFFF1F2)
              : const Color(0xFFEFF6FF),
          border: const Border(
            bottom: BorderSide(color: Color(0xFFFFFFFF), width: 1),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '₩ ${_formatPrice(price)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 42,
              child: Text(
                '$fakeQty주',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradePanelSection() {
    final item = _selectedMarketItem;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final price = _orderPrice;
    final total = (price * quantity).round();
    final afterCash = (_cash - total).round();

    return Container(
      height: 470,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주문',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildOrderTab('매수', _isBuyOrder),
              const SizedBox(width: 8),
              _buildOrderTab('매도', !_isBuyOrder),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '주문가격',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              item == null ? '-' : '₩ ${_formatPrice(price)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '수량',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildQuantityButton('-', _decreaseQuantity),
              const SizedBox(width: 6),
              _buildQuantityButton('+', _increaseQuantity),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderInfoRow(
                  '현재가',
                  item == null ? '-' : '₩ ${_formatPrice(item.currentPrice)}',
                ),
                _buildOrderInfoRow(
                  '선택가',
                  item == null ? '-' : '₩ ${_formatPrice(price)}',
                ),
                _buildOrderInfoRow('수량', '$quantity주'),
                _buildOrderInfoRow('주문금액', '₩ ${_formatPrice(total)}'),
                _buildOrderInfoRow(
                  _isBuyOrder ? '매수 후 현금' : '예상 입금',
                  _isBuyOrder
                      ? '₩ ${_formatPrice(afterCash)}'
                      : '₩ ${_formatPrice(total)}',
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _isTrading
                  ? null
                  : _isBuyOrder
                  ? _handleBuy
                  : _handleSell,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBuyOrder
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(
                _isBuyOrder ? '매수 주문' : '매도 주문',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTab(String label, bool selected) {
    final bool isBuyTab = label == '매수';

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _isBuyOrder = isBuyTab;
          });
        },
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? isBuyTab
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626)
                : Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? isBuyTab
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: 42,
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeHistorySection() {
    final totalCount = _tradeHistoryItems.length;
    final totalPages =
    totalCount == 0 ? 1 : (totalCount / _tradeHistoryPageSize).ceil();

    final safePage = _tradeHistoryPage.clamp(0, totalPages - 1);
    final startIndex = safePage * _tradeHistoryPageSize;
    final endIndex = min(startIndex + _tradeHistoryPageSize, totalCount);

    final pageItems = totalCount == 0
        ? <StockTradeHistoryModel>[]
        : _tradeHistoryItems.sublist(startIndex, endIndex);

    return Container(
      height: 420,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '최근 체결내역',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Text(
                '최신순 · ${safePage + 1} / $totalPages',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text('구분', style: _historyHeaderStyle),
                ),
                Expanded(
                  child: Text('종목', style: _historyHeaderStyle),
                ),
                SizedBox(
                  width: 46,
                  child: Text(
                    '수량',
                    textAlign: TextAlign.right,
                    style: _historyHeaderStyle,
                  ),
                ),
                SizedBox(
                  width: 86,
                  child: Text(
                    '체결가',
                    textAlign: TextAlign.right,
                    style: _historyHeaderStyle,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    '시간',
                    textAlign: TextAlign.right,
                    style: _historyHeaderStyle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: pageItems.isEmpty
                ? Center(
              child: Text(
                _isLoggedIn ? '거래내역이 없습니다.' : '로그인 후 표시됩니다.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            )
                : Column(
              children: pageItems
                  .map((item) => _buildTradeHistoryRow(item))
                  .toList(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildPageButton(
                label: '이전',
                enabled: safePage > 0,
                onPressed: () {
                  setState(() {
                    _tradeHistoryPage = safePage - 1;
                  });
                },
              ),
              const SizedBox(width: 8),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  '${safePage + 1} / $totalPages',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildPageButton(
                label: '다음',
                enabled: safePage < totalPages - 1,
                onPressed: () {
                  setState(() {
                    _tradeHistoryPage = safePage + 1;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTradeHistoryRow(StockTradeHistoryModel item) {
    final isBuy = item.tradeType == 'buy';
    final tradeLabel = isBuy ? '매수' : '매도';

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isBuy
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tradeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isBuy
                        ? const Color(0xFF047857)
                        : const Color(0xFFB91C1C),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.stockName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              '${item.quantity}주',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
          SizedBox(
            width: 86,
            child: Text(
              '₩ ${_formatPrice(item.price)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              _formatDateTime(item.createdAt),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton({
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

const TextStyle _historyHeaderStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w900,
  color: Color(0xFF64748B),
);

class _StockItem {
  final String id;
  final String code;
  final String name;
  final String market;
  final double currentPrice;
  final double changeRate;
  final String description;

  _StockItem({
    required this.id,
    required this.code,
    required this.name,
    required this.market,
    required this.currentPrice,
    required this.changeRate,
    required this.description,
  });
}