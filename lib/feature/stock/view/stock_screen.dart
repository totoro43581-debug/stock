import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/quest/service/daily_quest_service.dart';
import 'package:stock/feature/stock/model/stock_holding_model.dart';
import 'package:stock/feature/stock/model/stock_trade_history_model.dart';
import 'package:stock/feature/stock/repository/stock_repository.dart';
import 'package:stock/feature/stock/repository/stock_trade_repository.dart';
import 'package:stock/feature/wallet/model/wallet_model.dart';
import 'package:stock/feature/wallet/repository/wallet_repository.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  Timer? _priceTimer;
  final Random _random = Random();

  // 수정11차: 검색 / 주문 입력 컨트롤러
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController =
  TextEditingController(text: '1');

  // 수정11차: 상단 카테고리 / 필터 상태
  String _selectedCategoryTab = '전체';
  String _selectedMarketFilter = '전체';
  String _selectedSort = '등락률';
  bool _showOnlyOwned = false;

  // 수정11차: 주식 / 거래 / 지갑 repository 연결
  final StockRepository _stockRepository = StockRepository();
  final StockTradeRepository _stockTradeRepository = StockTradeRepository();
  final WalletRepository _walletRepository = WalletRepository();

  // 수정11차: wallet / 거래 진행 상태
  WalletModel? _wallet;
  bool _isWalletLoading = false;
  bool _isTrading = false;

  // 수정11차: 실제 DB 데이터 바인딩
  List<_StockItem> _marketItems = [];
  List<StockHoldingModel> _holdingItems = [];
  List<StockTradeHistoryModel> _tradeHistoryItems = [];

  _StockItem? _selectedMarketItem;

  SupabaseClient get _supabase => Supabase.instance.client;
  Session? get _session => _supabase.auth.currentSession;
  User? get _user => _supabase.auth.currentUser;

  bool get _isLoggedIn => _session != null && _user != null;

  // 수정11차: 공통 UI 기준값
  static const double _pageMaxWidth = 1400;
  static const double _sectionGap = 20;
  static const double _cardRadius = 20;
  static const double _cardPadding = 20;
  static const double _summaryCardMinHeight = 150;

  @override
  void initState() {
    super.initState();
    _completeOpenMarketQuest();
    _loadInitialData();
    _startPriceSimulation();

    _quantityController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _priceTimer?.cancel();
    super.dispose();
  }

  // 수정11차: 화면 최초 진입 데이터 로딩
  Future<void> _loadInitialData() async {
    await _loadMarketItems();
    await _loadWallet();
    await _loadHoldings();
    await _loadTradeHistory();
  }

  // 수정11차: 주식 화면 진입 퀘스트 완료
  Future<void> _completeOpenMarketQuest() async {
    try {
      await DailyQuestService.instance.completeOpenMarketQuest();
    } catch (_) {}
  }

  // 수정11차: stock_item 실제 종목 데이터 조회
  Future<void> _loadMarketItems() async {
    try {
      final rows = await _stockRepository.fetchActiveStocks();

      final items = rows.map((row) {
        return _StockItem(
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
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('종목 데이터를 불러오지 못했습니다: $e');
    }
  }

  // 수정11차: 로그인 사용자 wallet 조회 / 자동 생성
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

  // 수정11차: 로그인 사용자 보유종목 조회
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

  // 수정11차: 로그인 사용자 거래내역 조회
  Future<void> _loadTradeHistory() async {
    if (!_isLoggedIn || _user == null) {
      if (!mounted) return;
      setState(() {
        _tradeHistoryItems = [];
      });
      return;
    }

    try {
      final histories = await _stockTradeRepository.fetchTradeHistory(_user!.id);

      if (!mounted) return;
      setState(() {
        _tradeHistoryItems = histories;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('거래내역을 불러오지 못했습니다: $e');
    }
  }

  // 수정11차: 매수 / 매도 후 화면 데이터 새로고침
  Future<void> _reloadAfterTrade() async {
    await _loadWallet();
    await _loadHoldings();
    await _loadTradeHistory();
  }

  // 수정11차: DB market 값을 화면 필터 기준으로 변환
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

  // 수정11차: 실제 보유종목 기준 자산 계산
  double get _cash => (_wallet?.cashBalance ?? 0).toDouble();

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

    if (totalBuyAmount <= 0) {
      return 0;
    }

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
      result = result
          .where((item) => item.market == _selectedMarketFilter)
          .toList();
    }

    final String keyword = _searchController.text.trim().toLowerCase();
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
    final String prefix = value > 0 ? '+' : '';
    return '$prefix${_formatPrice(value)}';
  }

  String _formatSignedPercent(double value) {
    final String prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}%';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

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

  Future<void> _handleBuy() async {
    if (!_isLoggedIn || _user == null) {
      _showSnackBar('로그인 후 이용 가능합니다.');
      return;
    }

    if (_selectedMarketItem == null) {
      _showSnackBar('매수할 종목을 선택해주세요.');
      return;
    }

    final int quantity = int.tryParse(_quantityController.text.trim()) ?? 0;

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
        price: item.currentPrice,
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

    final int quantity = int.tryParse(_quantityController.text.trim()) ?? 0;

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
        price: item.currentPrice,
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
      borderRadius: BorderRadius.circular(_cardRadius),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_StockItem> filteredItems = _filteredItems;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 1280;
          final bool isTablet = constraints.maxWidth >= 900;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: _sectionGap),
                    _buildCategoryTabSection(),
                    const SizedBox(height: _sectionGap),
                    _buildSummarySection(),
                    const SizedBox(height: _sectionGap),
                    _buildLoginNoticeSection(),
                    const SizedBox(height: _sectionGap),
                    _buildFilterSection(),
                    const SizedBox(height: _sectionGap),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 8,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildStockListSection(filteredItems),
                                const SizedBox(height: _sectionGap),
                                _buildTradeHistorySection(),
                              ],
                            ),
                          ),
                          const SizedBox(width: _sectionGap),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildDetailSection(),
                                const SizedBox(height: _sectionGap),
                                _buildTradeSection(),
                                const SizedBox(height: _sectionGap),
                                _buildChartPlaceholderSection(),
                              ],
                            ),
                          ),
                        ],
                      )
                    else if (isTablet)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStockListSection(filteredItems),
                          const SizedBox(height: _sectionGap),
                          _buildDetailSection(),
                          const SizedBox(height: _sectionGap),
                          _buildTradeSection(),
                          const SizedBox(height: _sectionGap),
                          _buildChartPlaceholderSection(),
                          const SizedBox(height: _sectionGap),
                          _buildTradeHistorySection(),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStockListSection(filteredItems),
                          const SizedBox(height: 16),
                          _buildDetailSection(),
                          const SizedBox(height: 16),
                          _buildTradeSection(),
                          const SizedBox(height: 16),
                          _buildChartPlaceholderSection(),
                          const SizedBox(height: 16),
                          _buildTradeHistorySection(),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '주식',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '실제 보유 데이터 기준 자산, 보유종목, 거래내역이 표시됩니다.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFCBD5E1),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabSection() {
    final List<String> tabs = [
      '전체',
      '국내주식',
      '해외주식',
      'ETF',
      '테마',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final bool isSelected = _selectedCategoryTab == tab;

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategoryTab = tab;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Text(
                    tab,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final bool hasHolding = _holdingItems.isNotEmpty;

    final List<Widget> cards = [
      _buildSummaryCard(
        title: '총 자산',
        value: '₩ ${_formatPrice(_totalAsset)}',
        subValue: _isLoggedIn ? '현금 + 주식 평가금' : '비로그인 상태',
        valueColor: const Color(0xFF111827),
      ),
      _buildSummaryCard(
        title: '보유 현금',
        value: '₩ ${_formatPrice(_cash)}',
        subValue: !_isLoggedIn
            ? '비로그인 상태'
            : _isWalletLoading
            ? '지갑 불러오는 중'
            : 'wallet.cash_balance 기준',
        valueColor: const Color(0xFF111827),
      ),
      _buildSummaryCard(
        title: '주식 평가금',
        value: '₩ ${_formatPrice(_totalStockValue)}',
        subValue: hasHolding ? '보유 종목 현재가 기준' : '보유 종목 없음',
        valueColor: const Color(0xFF111827),
      ),
      _buildSummaryCard(
        title: '총 손익',
        value: '${_formatSignedPrice(_totalProfitAmount)}원',
        subValue: _formatSignedPercent(_totalProfitRate),
        valueColor: _changeColor(_totalProfitAmount),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 1100;
        final bool isTablet = constraints.maxWidth >= 700;

        if (isWide) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 16),
              ],
            ],
          );
        }

        if (isTablet) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i != cards.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subValue,
    required Color valueColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: _summaryCardMinHeight),
      padding: const EdgeInsets.all(_cardPadding),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginNoticeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _isLoggedIn ? Icons.info_outline_rounded : Icons.lock_outline_rounded,
            color:
            _isLoggedIn ? const Color(0xFF2563EB) : const Color(0xFFB45309),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isLoggedIn
                  ? '현재 계정 기준 보유 현금, 보유종목, 거래내역이 실제 DB와 연결되어 표시됩니다.'
                  : '비로그인 상태입니다. 로그인하지 않았으므로 자산, 보유종목, 거래내역은 표시되지 않습니다.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '종목명 / 종목코드 검색',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                ),
              ),
            ),
          ),
          _buildDropdownBox(
            value: _selectedMarketFilter,
            items: const ['전체', '국내', '해외'],
            onChanged: (value) {
              setState(() {
                _selectedMarketFilter = value!;
              });
            },
          ),
          _buildDropdownBox(
            value: _selectedSort,
            items: const ['등락률', '현재가', '이름'],
            onChanged: (value) {
              setState(() {
                _selectedSort = value!;
              });
            },
          ),
          FilterChip(
            label: const Text('보유 종목만'),
            selected: _showOnlyOwned,
            onSelected: (value) {
              setState(() {
                _showOnlyOwned = value;
              });
            },
            selectedColor: const Color(0xFFDBEAFE),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            labelStyle: TextStyle(
              color: _showOnlyOwned
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFF374151),
              fontWeight: FontWeight.w700,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownBox({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
              .toList(),
          onChanged: onChanged,
          borderRadius: BorderRadius.circular(14),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ),
    );
  }

  Widget _buildStockListSection(List<_StockItem> items) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '종목 목록',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 72),
              alignment: Alignment.center,
              child: Text(
                _isLoggedIn
                    ? '조건에 맞는 종목이 없습니다.'
                    : '종목 데이터가 없거나 필터 조건에 맞는 결과가 없습니다.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Column(
              children: [
                _buildListHeader(),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                for (int i = 0; i < items.length; i++) ...[
                  _buildListRow(items[i]),
                  if (i != items.length - 1)
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          Expanded(
            flex: 30,
            child: Text(
              '종목',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            flex: 20,
            child: Text(
              '현재가',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            flex: 16,
            child: Text(
              '등락률',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            flex: 16,
            child: Text(
              '보유수량',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              '평가손익',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListRow(_StockItem item) {
    final bool isSelected = _selectedMarketItem?.code == item.code;
    final StockHoldingModel? holding = _findHoldingByCode(item.code);
    final int holdingQuantity = holding?.quantity ?? 0;
    final double profitAmount = holding == null
        ? 0
        : (item.currentPrice - holding.averagePrice) * holding.quantity;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMarketItem = item;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8FAFC) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 30,
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            Expanded(
              flex: 20,
              child: Text(
                '₩ ${_formatPrice(item.currentPrice)}',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            Expanded(
              flex: 16,
              child: Text(
                _formatSignedPercent(item.changeRate),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _changeColor(item.changeRate),
                ),
              ),
            ),
            Expanded(
              flex: 16,
              child: Text(
                '${holdingQuantity}주',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            Expanded(
              flex: 18,
              child: Text(
                '${_formatSignedPrice(profitAmount)}원',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _changeColor(profitAmount),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection() {
    if (_selectedMarketItem == null) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 118),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: _cardDecoration(),
        child: const Center(
          child: Text(
            '선택된 종목이 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    final item = _selectedMarketItem!;
    final StockHoldingModel? holding = _findHoldingByCode(item.code);
    final int holdingQuantity = holding?.quantity ?? 0;
    final double averagePrice = holding?.averagePrice ?? 0;
    final double evaluatedAmount = item.currentPrice * holdingQuantity;
    final double profitAmount = holding == null
        ? 0
        : (item.currentPrice - holding.averagePrice) * holding.quantity;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_cardPadding),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '선택 종목 상세',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${item.code} · ${item.market}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildDetailMetric(
                  title: '현재가',
                  value: '₩ ${_formatPrice(item.currentPrice)}',
                  valueColor: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailMetric(
                  title: '등락률',
                  value: _formatSignedPercent(item.changeRate),
                  valueColor: _changeColor(item.changeRate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailMetric(
                  title: '보유수량',
                  value: '${holdingQuantity}주',
                  valueColor: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailMetric(
                  title: '평균단가',
                  value: holding == null ? '-' : '₩ ${_formatPrice(averagePrice)}',
                  valueColor: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailMetric(
                  title: '평가금액',
                  value: '₩ ${_formatPrice(evaluatedAmount)}',
                  valueColor: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailMetric(
                  title: '평가손익',
                  value: '${_formatSignedPrice(profitAmount)}원',
                  valueColor: _changeColor(profitAmount),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              item.description.isEmpty ? '종목 설명 데이터가 없습니다.' : item.description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMetric({
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_cardPadding),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '매수 / 매도',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '수량',
              hintText: '주문 수량 입력',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: _selectedMarketItem == null
                ? const Text('종목 선택 필요')
                : Builder(
              builder: (_) {
                final int qty =
                    int.tryParse(_quantityController.text) ?? 0;

                final double price = _selectedMarketItem!.currentPrice;

                final int total = (price * qty).round();

                final int afterCash = (_cash - total).round();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('현재가: ₩ ${_formatPrice(price)}'),
                    Text('수량: $qty주'),
                    const SizedBox(height: 8),
                    Text('결제금액: ₩ ${_formatPrice(total)}'),
                    Text('매수 후 현금: ₩ ${_formatPrice(afterCash)}'),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoggedIn && !_isTrading ? _handleBuy : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isTrading ? '처리 중' : '매수',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoggedIn && !_isTrading ? _handleSell : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isTrading ? '처리 중' : '매도',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartPlaceholderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_cardPadding),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '차트 영역',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
              ),
            ),
            child: const Center(
              child: Text(
                '차트는 종목 시세 데이터 연결 후 표시됩니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeHistorySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 체결내역',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          if (_tradeHistoryItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Text(
                _isLoggedIn
                    ? '거래내역이 없습니다.'
                    : '비로그인 상태에서는 거래내역이 표시되지 않습니다.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            )
          else
            Column(
              children: _tradeHistoryItems
                  .map((item) => _buildTradeHistoryRow(item))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTradeHistoryRow(StockTradeHistoryModel item) {
    final bool isBuy = item.tradeType == 'buy';
    final String tradeLabel = isBuy ? '매수' : '매도';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isBuy ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tradeLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                isBuy ? const Color(0xFF047857) : const Color(0xFFB91C1C),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              item.stockName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          Text(
            '${item.quantity}주',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 18),
          Text(
            '₩ ${_formatPrice(item.price)}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 110,
            child: Text(
              _formatDateTime(item.createdAt),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 수정12차: 가격 자동 변동 함수
  void _startPriceSimulation() {
    _priceTimer?.cancel();

    _priceTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _marketItems.isEmpty) return;

      setState(() {
        for (int i = 0; i < _marketItems.length; i++) {
          final item = _marketItems[i];

          final double changePercent = (_random.nextDouble() * 0.06) - 0.03;

          final double newPrice = (item.currentPrice * (1 + changePercent))
              .clamp(100.0, 100000000.0)
              .toDouble();

          final updatedItem = _StockItem(
            code: item.code,
            name: item.name,
            market: item.market,
            currentPrice: newPrice,
            changeRate: changePercent * 100,
            description: item.description,
          );

          _marketItems[i] = updatedItem;

          if (_selectedMarketItem?.code == item.code) {
            _selectedMarketItem = updatedItem;
          }
        }
      });
    });
  }
}

class _StockItem {
  final String code;
  final String name;
  final String market;
  final double currentPrice;
  final double changeRate;
  final String description;

  _StockItem({
    required this.code,
    required this.name,
    required this.market,
    required this.currentPrice,
    required this.changeRate,
    required this.description,
  });
}