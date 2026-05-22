import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stock/feature/quest/service/daily_quest_service.dart';
import 'package:stock/feature/stock/model/stock_candle_model.dart';
import 'package:stock/feature/stock/model/stock_holding_model.dart';
import 'package:stock/feature/stock/model/stock_item_view_model.dart';
import 'package:stock/feature/stock/model/stock_pending_order_model.dart';
import 'package:stock/feature/stock/model/stock_trade_history_model.dart';
import 'package:stock/feature/stock/repository/stock_price_repository.dart';
import 'package:stock/feature/stock/repository/stock_repository.dart';
import 'package:stock/feature/stock/repository/stock_trade_repository.dart';
import 'package:stock/feature/stock/service/stock_buy_service.dart';
import 'package:stock/feature/stock/service/stock_sell_service.dart';
import 'package:stock/feature/stock/view/widget/stock_chart_section.dart';
import 'package:stock/feature/stock/view/widget/stock_holding_section.dart';
import 'package:stock/feature/stock/view/widget/stock_market_list_section.dart';
import 'package:stock/feature/stock/view/widget/stock_order_book_section.dart';
import 'package:stock/feature/stock/view/widget/stock_pending_order_section.dart';
import 'package:stock/feature/stock/view/widget/stock_summary_section.dart';
import 'package:stock/feature/stock/view/widget/stock_tick_log_section.dart';
import 'package:stock/feature/stock/view/widget/stock_trade_history_section.dart';
import 'package:stock/feature/stock/view/widget/stock_trade_panel_section.dart';
import 'package:stock/feature/wallet/model/wallet_model.dart';
import 'package:stock/feature/wallet/repository/wallet_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // 수정75차: 매수/매도 로직 서비스 분리
  final StockBuyService _stockBuyService = StockBuyService();
  final StockSellService _stockSellService = StockSellService();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _priceController = TextEditingController();

  final ScrollController _pageScrollController = ScrollController();

  Timer? _realtimePriceTimer;

  bool _isRealtimeUpdating = false;
  bool _isWalletLoading = false;
  bool _isTrading = false;
  bool _showOnlyOwned = false;
  bool _isBuyOrder = true;
  bool _isMarketOrder = false;
  bool _isChartLoading = false;
  bool _isTickLogHovered = false;

  DateTime? _lastRealtimeUpdatedAt;

  WalletModel? _wallet;

  List<StockItemViewModel> _marketItems = [];
  List<StockHoldingModel> _holdingItems = [];
  List<StockTradeHistoryModel> _tradeHistoryItems = [];
  List<StockCandleModel> _selectedStockPrices = [];
  List<StockPendingOrderModel> _pendingOrderItems = [];

  // 수정90차: 최근 시장 뉴스
  List<Map<String, dynamic>> _recentNewsItems = [];

  // 수정98차: 주식시장 상태
  Map<String, dynamic>? _stockMarketStatus;

  StockItemViewModel? _selectedMarketItem;
  double? _selectedOrderPrice;
  double? _manualOrderPrice;

  double? _lockedPageOffset;

  String _selectedMarketFilter = '전체';
  String _selectedSort = '이름';
  String _selectedChartRange = '전체';

  // 수정91차: 주식 정보 통합 탭
  String _selectedInfoTab = 'info';

  int _tradeHistoryPage = 0;
  static const int _tradeHistoryPageSize = 9;

  SupabaseClient get _supabase => Supabase.instance.client;

  Session? get _session => _supabase.auth.currentSession;

  User? get _user => _supabase.auth.currentUser;

  bool get _isLoggedIn => _session != null && _user != null;

  // 수정99차: 현재 주식시장 장중 여부
  bool get _isStockMarketOpen {
    return _stockMarketStatus?['is_open'] == true;
  }

  static const double _pageMaxWidth = 1480;
  static const double _gap = 14;

// 수정92차: 정보 통합 탭 본문 고정 높이
  static const double _infoTabBodyHeight = 280;

// 수정96차: 뉴스 영향률 개발 표시 여부
// 개발 중 true, 실사용 전 false로 변경
  static const bool _showDebugNewsImpact = true;

// 수정97차: 주식 장 시간 개발 테스트용 강제 개장 여부
// 개발 중 true, 실사용 전 false로 변경
  static const bool _forceStockMarketOpenForDev = true;

  void _handleTickLogHoverChanged(bool isHovered) {
    if (!_pageScrollController.hasClients) return;

    setState(() {
      _isTickLogHovered = isHovered;
      _lockedPageOffset = isHovered ? _pageScrollController.offset : null;
    });
  }

  void _lockPageScrollWhileTickHovered() {
    if (!_isTickLogHovered) return;
    if (_lockedPageOffset == null) return;
    if (!_pageScrollController.hasClients) return;

    final currentOffset = _pageScrollController.offset;

    if ((currentOffset - _lockedPageOffset!).abs() < 0.5) return;

    _pageScrollController.jumpTo(_lockedPageOffset!);
  }

  @override
  void initState() {
    super.initState();

    _completeOpenMarketQuest();
    _loadInitialData();
    _startRealtimePriceUpdate();

    _quantityController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _realtimePriceTimer?.cancel();
    _pageScrollController.dispose();
    super.dispose();
  }

  Future<void> _completeOpenMarketQuest() async {
    try {
      await DailyQuestService.instance.completeOpenMarketQuest();
    } catch (_) {}
  }

  // 수정87차: 초기 진입 시 기존 현재가 기준 체결 확인 → 가격 갱신 → 갱신가 기준 체결 재확인
  Future<void> _loadInitialData() async {
    await _loadMarketItems();
    await _loadWallet();
    await _loadHoldings();
    await _loadTradeHistory();
    await _loadPendingOrders();

    try {
      await _stockTradeRepository.processPendingOrders();
    } catch (e) {
      debugPrint('초기 기존 현재가 기준 지정가 자동체결 실패: $e');
    }

    await _loadWallet();
    await _loadHoldings();
    await _loadTradeHistory();
    await _loadPendingOrders();

    try {
      await _applyNewsOrSimulatePriceUpdate();
    } catch (e) {
      debugPrint('가상 거래량 초기 갱신 실패: $e');
    }

    await _loadMarketItems();
    await _loadHoldings();

    try {
      await _stockTradeRepository.processPendingOrders();
    } catch (e) {
      debugPrint('초기 가격 갱신 후 지정가 자동체결 실패: $e');
    }

    await _loadWallet();
    await _loadHoldings();
    await _loadTradeHistory();
    await _loadPendingOrders();
    await _loadRecentNewsItems();
    await _loadStockMarketStatus();

    if (!mounted) return;

    setState(() {
      _lastRealtimeUpdatedAt = DateTime.now();
    });
  }

  // 수정97차: 장중에만 뉴스/가격 갱신, 장 마감 후 주식 가격 변동 방지
  Future<void> _applyNewsOrSimulatePriceUpdate() async {
    final newsResult = await _stockRepository.applyActiveStockNewsEvents(
      forceOpen: _forceStockMarketOpenForDev,
    );

    final bool success = newsResult['success'] == true;
    final bool marketOpen = newsResult['market_open'] == true;

    final int appliedNewsCount =
    ((newsResult['applied_news_count'] ?? 0) as num).toInt();

    final int appliedStockCount =
    ((newsResult['applied_stock_count'] ?? 0) as num).toInt();

    if (!marketOpen) {
      debugPrint('주식 장 마감 상태: 가격 갱신 중단');
      return;
    }

    if (success && appliedNewsCount > 0 && appliedStockCount > 0) {
      debugPrint(
        '활성 뉴스 반복 반영 완료: 뉴스 $appliedNewsCount건 / 종목 $appliedStockCount개',
      );
      return;
    }

    await _stockPriceRepository.simulateStockPrices();
  }

  // 수정87차: 1분 자동 갱신 시 기존 현재가 기준 체결 확인 → 가격 갱신 → 갱신가 기준 체결 재확인
  void _startRealtimePriceUpdate() {
    _realtimePriceTimer?.cancel();

    _realtimePriceTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!mounted || _isRealtimeUpdating) return;

      _isRealtimeUpdating = true;

      try {
        final beforeCount = _pendingOrderItems.length;

        // 수정87차: 가격이 바뀌기 전, 이미 현재가와 맞아 있는 미체결 주문 우선 처리
        await _stockTradeRepository.processPendingOrders();

        await _loadPendingOrders();

        if (_isLoggedIn) {
          await _loadWallet();
          await _loadHoldings();
          await _loadTradeHistory();
        }

        // 수정87차: 1분 단위 가격/거래량 시뮬레이션 실행
        await _applyNewsOrSimulatePriceUpdate();

        await _loadMarketItems();
        await _loadRecentNewsItems();
        await _loadStockMarketStatus();

        // 수정87차: 가격 변동 후 새로 주문가와 일치한 미체결 주문 재확인
        await _stockTradeRepository.processPendingOrders();

        await _loadPendingOrders();

        if (_isLoggedIn) {
          await _loadWallet();
          await _loadHoldings();
          await _loadTradeHistory();
        }

        final afterCount = _pendingOrderItems.length;

        if (mounted && beforeCount > afterCount) {
          _showSnackBar('지정가 주문이 체결되었습니다.');
        }

        final selectedItem = _selectedMarketItem;
        if (selectedItem != null) {
          await _loadStockChart(
            selectedItem.id,
            selectedItem.name,
            showLoading: false,
          );
        }

        if (!mounted) return;

        setState(() {
          _lastRealtimeUpdatedAt = DateTime.now();
        });
      } catch (e) {
        debugPrint('가상 거래량 자동 갱신 실패: $e');

        if (mounted) {
          _showSnackBar('가상 거래량 갱신 실패: $e');
        }
      } finally {
        _isRealtimeUpdating = false;
      }
    });
  }

  Future<void> _loadMarketItems() async {
    try {
      final rows = await _stockRepository.fetchActiveStocks();

      final items = rows.map((row) {
        return StockItemViewModel(
          id: row['id'].toString(),
          code: (row['code'] ?? '').toString(),
          name: (row['name'] ?? '').toString(),
          market: _mapMarketLabel((row['market'] ?? '').toString()),
          currentPrice: ((row['current_price'] ?? 0) as num).toDouble(),
          changeRate: ((row['change_rate'] ?? 0) as num).toDouble(),
          virtualBuyVolume: ((row['virtual_buy_volume'] ?? 0) as num).toInt(),
          virtualSellVolume: ((row['virtual_sell_volume'] ?? 0) as num).toInt(),
          tradeVolume: ((row['trade_volume'] ?? 0) as num).toInt(),
          tradeAmount: ((row['trade_amount'] ?? 0) as num).toDouble(),

          // 수정88차: 현실형 가상 종목 정보 매핑
          description:
              (row['company_description'] ?? '').toString().trim().isEmpty
              ? '등록된 기업 설명이 없습니다.'
              : (row['company_description'] ?? '').toString(),
          stockType: (row['stock_type'] ?? 'domestic_large').toString(),
          sector: (row['sector'] ?? 'general').toString(),
          marketCapLevel: (row['market_cap_level'] ?? 'mid').toString(),
          volatilityLevel: (row['volatility_level'] ?? 'normal').toString(),
          growthScore: ((row['growth_score'] ?? 50) as num).toInt(),
          stabilityScore: ((row['stability_score'] ?? 50) as num).toInt(),
          newsSensitivity: ((row['news_sensitivity'] ?? 1.00) as num)
              .toDouble(),
          delistingRiskScore: ((row['delisting_risk_score'] ?? 0) as num)
              .toInt(),
          listingStatus: (row['listing_status'] ?? 'listed').toString(),
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
            _selectedMarketItem = items.firstWhere(
              (item) => item.code == selectedCode,
            );
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
      final histories = await _stockTradeRepository.fetchTradeHistory(
        _user!.id,
      );

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

  Future<void> _loadPendingOrders() async {
    if (!_isLoggedIn || _user == null) {
      if (!mounted) return;
      setState(() {
        _pendingOrderItems = [];
      });
      return;
    }

    try {
      final orders = await _stockTradeRepository.fetchPendingOrders(_user!.id);

      if (!mounted) return;
      setState(() {
        _pendingOrderItems = orders;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('미체결 주문을 불러오지 못했습니다: $e');
    }
  }

  // 수정90차: 최근 시장 뉴스 조회
  Future<void> _loadRecentNewsItems() async {
    try {
      final newsItems = await _stockRepository.fetchRecentStockNewsEvents();

      if (!mounted) return;

      setState(() {
        _recentNewsItems = newsItems;
      });
    } catch (e) {
      debugPrint('최근 시장 뉴스 조회 실패: $e');
    }
  }

  // 수정98차: 주식시장 상태 조회
  Future<void> _loadStockMarketStatus() async {
    try {
      final status = await _stockRepository.fetchStockMarketStatus(
        forceOpen: _forceStockMarketOpenForDev,
      );

      if (!mounted) return;

      setState(() {
        _stockMarketStatus = status;
      });
    } catch (e) {
      debugPrint('주식시장 상태 조회 실패: $e');
    }
  }

  Future<void> _cancelPendingOrder(String orderId) async {
    if (_user == null) {
      _showSnackBar('로그인이 필요합니다.');
      return;
    }

    try {
      await _stockTradeRepository.cancelPendingOrder(
        userId: _user!.id,
        orderId: orderId,
      );

      await _reloadAfterTrade();

      _showSnackBar('주문이 취소되었습니다.');
    } catch (e) {
      _showSnackBar('주문 취소 실패: $e');
    }
  }

  // 수정70차: 차트 범위에 따른 캔들 interval_type 매핑
  String _chartIntervalType(String range) {
    switch (range) {
      case '1분':
        return '1m';
      case '5분':
        return '5m';
      case '15분':
        return '15m';
      case '30분':
        return '30m';
      case '1시간':
        return '1h';
      case '3시간':
        return '3h';
      case '1주':
      case '1개월':
      case '3개월':
      case '1년':
      case '전체':
        return '1m';
      default:
        return '1m';
    }
  }

  // 수정74차: 자동갱신 시 차트 전체 깜빡임 방지
  Future<void> _loadStockChart(
    String stockId,
    String stockName, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      setState(() {
        _isChartLoading = true;
      });
    }

    try {
      final prices = await _stockPriceRepository.fetchCandlesByStockId(
        stockId,
        intervalType: _chartIntervalType(_selectedChartRange),
      );

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

      if (showLoading) {
        setState(() {
          _isChartLoading = false;
        });
      }
    }
  }

  // 수정47차: 거래 직후 시장/차트까지 즉시 갱신
  Future<void> _reloadAfterTrade() async {
    await _loadMarketItems();
    await _loadWallet();
    await _loadHoldings();
    await _loadTradeHistory();
    await _loadPendingOrders();
    await _loadRecentNewsItems();

    final selectedItem = _selectedMarketItem;

    if (selectedItem != null) {
      await _loadStockChart(
        selectedItem.id,
        selectedItem.name,
        showLoading: false,
      );
    }
  }

  Future<void> _processPendingOrdersManually() async {
    final beforeCount = _pendingOrderItems.length;

    try {
      await _stockTradeRepository.processPendingOrders();

      await _loadWallet();
      await _loadHoldings();
      await _loadTradeHistory();
      await _loadPendingOrders();

      final afterCount = _pendingOrderItems.length;

      if (!mounted) return;

      if (beforeCount > afterCount) {
        _showSnackBar('지정가 주문이 체결되었습니다.');
      } else {
        _showSnackBar('체결 가능한 지정가 주문이 없습니다.');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('지정가 체결 확인 실패: $e');
    }
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
    if (_isMarketOrder) {
      return _selectedMarketItem?.currentPrice ?? 0;
    }

    return _manualOrderPrice ??
        _selectedOrderPrice ??
        _selectedMarketItem?.currentPrice ??
        0;
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

  StockItemViewModel? _findMarketItemByCode(String code) {
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

  double get _availableBuyCash {
    return _stockBuyService.availableCash(
      cash: _cash,
      pendingOrders: _pendingOrderItems,
    );
  }

  double get _reservedBuyAmount {
    return _cash - _availableBuyCash;
  }

  int get _selectedHoldingQuantity {
    final item = _selectedMarketItem;
    if (item == null) return 0;

    final holding = _findHoldingByCode(item.code);
    return holding?.quantity ?? 0;
  }

  int get _availableSellQuantity {
    final item = _selectedMarketItem;
    if (item == null) return 0;

    final holding = _findHoldingByCode(item.code);

    return _stockSellService.availableSellQuantity(
      holding: holding,
      pendingOrders: _pendingOrderItems,
      stockCode: item.code,
    );
  }

  int get _reservedSellQuantity {
    return _selectedHoldingQuantity - _availableSellQuantity;
  }

  List<StockItemViewModel> get _filteredItems {
    List<StockItemViewModel> result = List.of(_marketItems);

    if (_selectedMarketFilter == '국내주식') {
      result = result.where((item) {
        return item.stockType == 'domestic_large' ||
            item.stockType == 'domestic_growth' ||
            item.stockType == 'domestic_penny';
      }).toList();
    } else if (_selectedMarketFilter == '해외주식') {
      result = result.where((item) {
        return item.stockType == 'overseas_large' ||
            item.stockType == 'overseas_growth' ||
            item.stockType == 'overseas_penny';
      }).toList();
    } else if (_selectedMarketFilter == 'ETF') {
      result = result.where((item) => item.stockType == 'etf').toList();
    } else if (_selectedMarketFilter == '테마주') {
      result = result.where((item) => item.stockType == 'theme').toList();
    }

    final keyword = _searchController.text.trim().toLowerCase();

    if (keyword.isNotEmpty) {
      result = result.where((item) {
        return item.name.toLowerCase().contains(keyword) ||
            item.code.toLowerCase().contains(keyword) ||
            item.description.toLowerCase().contains(keyword);
      }).toList();
    }

    if (_showOnlyOwned) {
      result = result.where((item) {
        return _holdingItems.any((holding) => holding.stockCode == item.code);
      }).toList();
    }

    switch (_selectedSort) {
      case '거래대금':
        result.sort((a, b) => b.tradeAmount.compareTo(a.tradeAmount));
        break;
      case '체결강도':
        result.sort((a, b) {
          final aStrength = a.virtualSellVolume <= 0
              ? 0
              : (a.virtualBuyVolume / a.virtualSellVolume);

          final bStrength = b.virtualSellVolume <= 0
              ? 0
              : (b.virtualBuyVolume / b.virtualSellVolume);

          return bStrength.compareTo(aStrength);
        });
        break;
      case '거래량':
        result.sort((a, b) => b.tradeVolume.compareTo(a.tradeVolume));
        break;
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  void _handlePriceChanged(String value) {
    final price = double.tryParse(value.trim()) ?? 0;

    setState(() {
      _manualOrderPrice = price <= 0 ? null : price;
      _selectedOrderPrice = _manualOrderPrice;
    });
  }

  void _normalizeQuantity() {
    final text = _quantityController.text.trim();
    final quantity = int.tryParse(text) ?? 0;

    if (quantity <= 0) {
      _quantityController.text = '1';
      _quantityController.selection = TextSelection.fromPosition(
        TextPosition(offset: _quantityController.text.length),
      );
    }
  }

  void _resetQuantityAfterOrder() {
    setState(() {
      _quantityController.text = '1';
    });
  }

  void _setMaxQuantity() {
    final item = _selectedMarketItem;

    if (item == null) {
      _quantityController.text = '';
      return;
    }

    if (_isBuyOrder) {
      final int maxBuyQuantity = _orderPrice <= 0
          ? 0
          : (_availableBuyCash / _orderPrice).floor();

      _quantityController.text = maxBuyQuantity <= 0
          ? ''
          : maxBuyQuantity.toString();
      return;
    }

    final int maxSellQuantity = _availableSellQuantity;

    _quantityController.text = maxSellQuantity <= 0
        ? ''
        : maxSellQuantity.toString();
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

    // 수정99차: 휴장 중 시장가 매수 차단
    if (!_isStockMarketOpen && _isMarketOrder) {
      _showSnackBar('휴장 중에는 시장가 매수가 불가능합니다. 지정가 예약 주문만 가능합니다.');
      return;
    }

    _normalizeQuantity();

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

      final message = await _stockBuyService.buy(
        tradeRepository: _stockTradeRepository,
        userId: _user!.id,
        item: _selectedMarketItem!,
        orderPrice: _orderPrice,
        quantity: quantity,
        cash: _cash,
        isMarketOrder: _isMarketOrder,
        pendingOrders: _pendingOrderItems,
      );

      await _reloadAfterTrade();

      if (!mounted) return;
      _resetQuantityAfterOrder();
      _showSnackBar(message);
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

    // 수정99차: 휴장 중 시장가 매도 차단
    if (!_isStockMarketOpen && _isMarketOrder) {
      _showSnackBar('휴장 중에는 시장가 매도가 불가능합니다. 지정가 예약 주문만 가능합니다.');
      return;
    }

    _normalizeQuantity();

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
      final holding = _findHoldingByCode(item.code);

      final message = await _stockSellService.sell(
        tradeRepository: _stockTradeRepository,
        userId: _user!.id,
        item: item,
        holding: holding,
        orderPrice: _orderPrice,
        quantity: quantity,
        isMarketOrder: _isMarketOrder,
        pendingOrders: _pendingOrderItems,
      );

      await _reloadAfterTrade();

      if (!mounted) return;
      _resetQuantityAfterOrder();
      _showSnackBar(message);
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

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
        child: NotificationListener<ScrollNotification>(
          onNotification: (_) {
            _lockPageScrollWhileTickHovered();
            return false;
          },
          child: ListView(
            controller: _pageScrollController,
            physics: _isTickLogHovered
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StockSummarySection(
                        totalAsset: _totalAsset,
                        cash: _cash,
                        totalStockValue: _totalStockValue,
                        totalProfitAmount: _totalProfitAmount,
                        totalProfitRate: _totalProfitRate,
                        isWalletLoading: _isWalletLoading,
                      ),

                      const SizedBox(height: _gap),

                      // 수정98차: 주식시장 상태 표시
                      _buildStockMarketStatusSection(),

                      const SizedBox(height: _gap),

                      StockHoldingSection(
                        holdingItems: _holdingItems,
                        marketItems: _marketItems,
                        isLoggedIn: _isLoggedIn,
                        onSelectHolding: (item) {
                          setState(() {
                            _selectedMarketItem = item;
                            _selectedOrderPrice = null;
                            _manualOrderPrice = null;
                            _priceController.text = item.currentPrice
                                .toStringAsFixed(0);
                          });

                          _loadStockChart(item.id, item.name);
                        },
                      ),
                      const SizedBox(height: _gap),
                      _buildTradingLayout(filteredItems),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 수정98차: 주식시장 상태 카드
  Widget _buildStockMarketStatusSection() {
    final status = _stockMarketStatus;

    if (status == null) {
      return Container(
        width: double.infinity,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Text(
          '주식시장 상태를 불러오는 중입니다.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
          ),
        ),
      );
    }

    final bool isOpen = status['is_open'] == true;
    final String statusLabel = (status['status_label'] ?? '상태미정').toString();
    final String nextStatus = (status['next_status'] ?? '-').toString();
    final int remainingMinutes =
    ((status['remaining_minutes'] ?? 0) as num).toInt();

    final Color backgroundColor =
    isOpen ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED);

    final Color borderColor =
    isOpen ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA);

    final Color pointColor =
    isOpen ? const Color(0xFF16A34A) : const Color(0xFFF97316);

    final String description = isOpen
        ? '가격 변동 · 뉴스 반영 · 주문 체결 진행'
        : '가격 변동 정지 · 예약 주문 중심 운영';

    return Container(
      width: double.infinity,
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: pointColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '주식시장 $statusLabel',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: pointColor,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              '다음 $nextStatus까지 ${remainingMinutes}분',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF374151),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: const Text(
              '90분 장중 / 30분 휴장',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF374151),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradingLayout(List<StockItemViewModel> filteredItems) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: StockChartSection(
                selectedItem: _selectedMarketItem,
                prices: _selectedStockPrices,
                isChartLoading: _isChartLoading,
                lastRealtimeUpdatedAt: _lastRealtimeUpdatedAt,
                selectedRange: _selectedChartRange,
                onRangeChanged: (range) {
                  setState(() {
                    _selectedChartRange = range;
                  });

                  final item = _selectedMarketItem;
                  if (item != null) {
                    _loadStockChart(item.id, item.name);
                  }
                },
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              flex: 3,
              child: StockMarketListSection(
                items: filteredItems,
                selectedItem: _selectedMarketItem,
                holdings: _holdingItems,
                searchController: _searchController,
                selectedMarketFilter: _selectedMarketFilter,
                selectedSort: _selectedSort,
                onMarketChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedMarketFilter = value;
                  });
                },
                onSortChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedSort = value;
                  });
                },
                onSearchChanged: () {
                  setState(() {});
                },
                onSelectItem: (item) {
                  setState(() {
                    _selectedMarketItem = item;
                    _selectedOrderPrice = null;
                    _manualOrderPrice = null;
                    _priceController.text = item.currentPrice.toStringAsFixed(
                      0,
                    );
                  });

                  _loadStockChart(item.id, item.name);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: _gap),

        // 수정91차: 선택 종목 정보 / 뉴스 / 미체결 / 실시간 체결 통합 탭
        _buildStockInfoTabSection(),

        const SizedBox(height: _gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: _buildBottomTradingArea()),
            const SizedBox(width: _gap),
            Expanded(
              flex: 3,
              child: StockTradePanelSection(
                selectedItem: _selectedMarketItem,
                selectedHolding: _selectedMarketItem == null
                    ? null
                    : _findHoldingByCode(_selectedMarketItem!.code),
                quantityController: _quantityController,
                priceController: _priceController,
                orderPrice: _orderPrice,
                cash: _cash,
                availableBuyCash: _availableBuyCash,
                reservedBuyAmount: _reservedBuyAmount,
                holdingQuantity: _selectedHoldingQuantity,
                availableSellQuantity: _availableSellQuantity,
                reservedSellQuantity: _reservedSellQuantity,
                isBuyOrder: _isBuyOrder,
                isMarketOrder: _isMarketOrder,
                isTrading: _isTrading,
                onChangeOrderType: (isBuy) {
                  setState(() {
                    _isBuyOrder = isBuy;
                    _quantityController.text = '1';
                  });
                },
                onChangeOrderMode: (isMarket) {
                  // 수정100차: 휴장 중 시장가 모드 선택 차단
                  if (isMarket && !_isStockMarketOpen) {
                    _showSnackBar('휴장 중에는 시장가 주문을 사용할 수 없습니다. 지정가 예약 주문만 가능합니다.');

                    setState(() {
                      _isMarketOrder = false;

                      if (_selectedMarketItem != null) {
                        _manualOrderPrice = _selectedMarketItem!.currentPrice;
                        _selectedOrderPrice = _selectedMarketItem!.currentPrice;
                        _priceController.text = _selectedMarketItem!.currentPrice
                            .toStringAsFixed(0);
                      }
                    });

                    return;
                  }

                  setState(() {
                    _isMarketOrder = isMarket;

                    if (isMarket) {
                      _manualOrderPrice = null;
                      _selectedOrderPrice = null;
                      _priceController.clear();
                    } else if (_selectedMarketItem != null) {
                      _manualOrderPrice = _selectedMarketItem!.currentPrice;
                      _selectedOrderPrice = _selectedMarketItem!.currentPrice;
                      _priceController.text = _selectedMarketItem!.currentPrice
                          .toStringAsFixed(0);
                    }
                  });
                },
                onDecreaseQuantity: _decreaseQuantity,
                onIncreaseQuantity: _increaseQuantity,
                onSetMaxQuantity: _setMaxQuantity,
                onBuy: _handleBuy,
                onSell: _handleSell,
                onPriceChanged: _handlePriceChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 수정91차: 선택 종목 정보 / 뉴스 / 미체결 / 실시간 체결 통합 탭
  Widget _buildStockInfoTabSection() {
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
          Row(
            children: [
              _buildInfoTabButton(keyName: 'info', label: '선택 종목 정보'),
              const SizedBox(width: 8),
              _buildInfoTabButton(keyName: 'news', label: '뉴스'),
              const SizedBox(width: 8),
              _buildInfoTabButton(keyName: 'pending', label: '미체결 내역'),
              const SizedBox(width: 8),
              _buildInfoTabButton(keyName: 'tick', label: '체결내역'),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoTabBody(),
        ],
      ),
    );
  }

  Widget _buildInfoTabButton({required String keyName, required String label}) {
    final bool isSelected = _selectedInfoTab == keyName;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedInfoTab = keyName;
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF111827)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isSelected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTabBody() {
    switch (_selectedInfoTab) {
      case 'news':
        return SizedBox(
          height: _infoTabBodyHeight,
          child: _buildMarketNewsTabBody(),
        );

      case 'pending':
        return SizedBox(
          height: _infoTabBodyHeight,
          child: StockPendingOrderSection(
            pendingOrders: _pendingOrderItems,
            isLoggedIn: _isLoggedIn,
            onCancelOrder: _cancelPendingOrder,
          ),
        );

      case 'tick':
        return SizedBox(
          height: _infoTabBodyHeight,
          child: StockTickLogSection(
            tradeHistoryItems: _tradeHistoryItems,
            onHoverChanged: _handleTickLogHoverChanged,
          ),
        );

      case 'info':
      default:
        return SizedBox(
          height: _infoTabBodyHeight,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: _buildSelectedStockInfoTabBody(),
          ),
        );
    }
  }

  Widget _buildSelectedStockInfoTabBody() {
    final item = _selectedMarketItem;

    if (item == null) {
      return const Text(
        '종목을 선택하면 기업 설명이 표시됩니다.',
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              item.code,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
              ),
            ),
            const Spacer(),
            _buildListingStatusBadge(item.listingStatus),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildStockInfoCard(
                label: '종목 분류',
                value: _stockTypeLabel(item.stockType),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStockInfoCard(
                label: '업종',
                value: _sectorLabel(item.sector),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStockInfoCard(
                label: '규모',
                value: _marketCapLabel(item.marketCapLevel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStockInfoCard(
                label: '변동성',
                value: _volatilityLabel(item.volatilityLevel),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            item.description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.65,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildStockMetricCard(
                label: '성장성',
                value: '${item.growthScore}점',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStockMetricCard(
                label: '안정성',
                value: '${item.stabilityScore}점',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStockMetricCard(
                label: '뉴스 민감도',
                value: '× ${item.newsSensitivity.toStringAsFixed(2)}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStockMetricCard(
                label: '상폐 위험도',
                value: '${item.delistingRiskScore}점',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMarketNewsTabBody() {
    if (_recentNewsItems.isEmpty) {
      return const Center(
        child: Text(
          '표시할 시장 뉴스가 없습니다.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      itemCount: _recentNewsItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildMarketNewsItem(_recentNewsItems[index]);
      },
    );
  }

  Widget _buildMarketNewsItem(Map<String, dynamic> news) {
    final String title = (news['title'] ?? '제목 없음').toString();

    final String content = (news['content'] ?? news['body'] ?? '내용 없음')
        .toString();

    final String targetType = (news['target_type'] ?? '').toString();
    final String targetValue = (news['target_value'] ?? '').toString();
    final String sentiment = (news['sentiment'] ?? '').toString();

    final bool isRealWorldBased = news['is_real_world_based'] == true;

    final String newsStatusLabel = _newsActiveStatusLabel(news);
    final bool isActive = newsStatusLabel == '영향중';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNewsDirectionDot(sentiment),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildNewsBadge(
                      newsStatusLabel,
                      isActive
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF3F4F6),
                      isActive
                          ? const Color(0xFF15803D)
                          : const Color(0xFF374151),
                    ),
                    const SizedBox(width: 6),
                    _buildNewsBadge(
                      isRealWorldBased ? '실제뉴스 기반' : '가상뉴스',
                      isRealWorldBased
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFF3F4F6),
                      isRealWorldBased
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF374151),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildNewsSmallInfo(
                      '대상',
                      _newsTargetLabel(targetType, targetValue),
                    ),
                    const SizedBox(width: 6),
                    _buildNewsSmallInfo(
                      '영향',
                      _sentimentLabel(sentiment),
                    ),
                    const SizedBox(width: 6),
                    _buildNewsSmallInfo(
                      '상태',
                      newsStatusLabel,
                    ),
                    if (_showDebugNewsImpact) ...[
                      const SizedBox(width: 6),
                      _buildNewsSmallInfo(
                        '잔여',
                        _newsRemainingLabel(news),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsDirectionDot(String sentiment) {
    final Color color = sentiment == 'positive'
        ? const Color(0xFFDC2626)
        : sentiment == 'negative'
        ? const Color(0xFF2563EB)
        : const Color(0xFF6B7280);

    return Container(
      width: 9,
      height: 9,
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildNewsBadge(String label, Color backgroundColor, Color textColor) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildNewsSmallInfo(String label, String value) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        '$label: $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  String _newsTargetLabel(String targetType, String targetValue) {
    if (targetType == 'sector') {
      return _sectorLabel(targetValue);
    }

    if (targetType == 'company') {
      return targetValue;
    }

    if (targetType == 'market') {
      if (targetValue == 'domestic') return '국내시장';
      if (targetValue == 'overseas') return '해외시장';
      return targetValue;
    }

    if (targetType == 'global') {
      return '전체시장';
    }

    return '미분류';
  }

  String _sentimentLabel(String value) {
    switch (value) {
      case 'positive':
        return '호재';
      case 'negative':
        return '악재';
      case 'neutral':
        return '중립';
      default:
        return '미정';
    }
  }

  // 수정95차: 뉴스 지속 반영 상태 표시
  String _newsActiveStatusLabel(Map<String, dynamic> news) {
    final String status = (news['status'] ?? '').toString();

    final DateTime now = DateTime.now();

    final DateTime? activeFrom = news['active_from'] == null
        ? null
        : DateTime.tryParse(news['active_from'].toString())?.toLocal();

    final DateTime? activeUntil = news['active_until'] == null
        ? null
        : DateTime.tryParse(news['active_until'].toString())?.toLocal();

    final double remainingImpactRate =
    ((news['remaining_impact_rate'] ?? 0) as num).toDouble();

    if (remainingImpactRate.abs() <= 0.001) {
      return '반영완료';
    }

    if (status == 'expired') {
      return '만료';
    }

    if (activeFrom != null && now.isBefore(activeFrom)) {
      return '대기';
    }

    if (activeUntil != null && now.isAfter(activeUntil)) {
      return '만료';
    }

    if (activeFrom != null &&
        activeUntil != null &&
        now.isAfter(activeFrom) &&
        now.isBefore(activeUntil)) {
      return '영향중';
    }

    if (status == 'published') {
      return '공개';
    }

    if (status == 'applied') {
      return '반영';
    }

    return _newsStatusLabel(status);
  }

  String _newsRemainingLabel(Map<String, dynamic> news) {
    final double remainingImpactRate =
    ((news['remaining_impact_rate'] ?? 0) as num).toDouble();

    if (remainingImpactRate.abs() <= 0.001) {
      return '0.00%';
    }

    return '${remainingImpactRate.toStringAsFixed(2)}%';
  }

  String _newsStatusLabel(String value) {
    switch (value) {
      case 'draft':
        return '작성중';
      case 'scheduled':
        return '예약';
      case 'published':
        return '공개';
      case 'applied':
        return '반영';
      case 'expired':
        return '만료';
      default:
        return '미정';
    }
  }

  Widget _buildStockInfoCard({required String label, required String value}) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingStatusBadge(String status) {
    final String label = _listingStatusLabel(status);
    final Color backgroundColor = _listingStatusBackgroundColor(status);
    final Color textColor = _listingStatusTextColor(status);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildStockMetricCard({required String label, required String value}) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  String _stockTypeLabel(String value) {
    switch (value) {
      case 'domestic_large':
        return '국내 대형주';
      case 'domestic_growth':
        return '국내 성장주';
      case 'domestic_penny':
        return '국내 잡주';
      case 'overseas_large':
        return '해외 대형주';
      case 'overseas_growth':
        return '해외 성장주';
      case 'overseas_penny':
        return '해외 잡주';
      case 'theme':
        return '테마주';
      case 'etf':
        return 'ETF';
      default:
        return '기타';
    }
  }

  String _sectorLabel(String value) {
    switch (value) {
      case 'semiconductor':
        return '반도체';
      case 'platform':
        return '플랫폼';
      case 'automobile':
        return '자동차';
      case 'battery':
        return '2차전지';
      case 'bio':
        return '바이오';
      case 'finance':
        return '금융';
      case 'defense':
        return '방산';
      case 'energy':
        return '에너지';
      case 'game':
        return '게임';
      case 'robot':
        return '로봇';
      default:
        return '종합';
    }
  }

  String _marketCapLabel(String value) {
    switch (value) {
      case 'mega':
        return '초대형';
      case 'large':
        return '대형';
      case 'mid':
        return '중형';
      case 'small':
        return '소형';
      case 'micro':
        return '초소형';
      case 'index':
        return '지수형';
      default:
        return '미분류';
    }
  }

  String _volatilityLabel(String value) {
    switch (value) {
      case 'stable':
        return '낮음';
      case 'normal':
        return '보통';
      case 'high':
        return '높음';
      case 'extreme':
        return '매우 높음';
      default:
        return '보통';
    }
  }

  String _listingStatusLabel(String value) {
    switch (value) {
      case 'pre_listing':
        return '상장예정';
      case 'listed':
        return '정상상장';
      case 'warning':
        return '투자경고';
      case 'suspended':
        return '거래정지';
      case 'delisted':
        return '상장폐지';
      default:
        return '상태미정';
    }
  }

  Color _listingStatusBackgroundColor(String value) {
    switch (value) {
      case 'listed':
        return const Color(0xFFDCFCE7);
      case 'warning':
        return const Color(0xFFFEF3C7);
      case 'suspended':
        return const Color(0xFFFEE2E2);
      case 'delisted':
        return const Color(0xFFE5E7EB);
      case 'pre_listing':
        return const Color(0xFFDBEAFE);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _listingStatusTextColor(String value) {
    switch (value) {
      case 'listed':
        return const Color(0xFF15803D);
      case 'warning':
        return const Color(0xFFB45309);
      case 'suspended':
        return const Color(0xFFDC2626);
      case 'delisted':
        return const Color(0xFF4B5563);
      case 'pre_listing':
        return const Color(0xFF1D4ED8);
      default:
        return const Color(0xFF374151);
    }
  }

  Widget _buildBottomTradingArea() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 45,
          child: StockOrderBookSection(
            selectedItem: _selectedMarketItem,
            selectedOrderPrice: _selectedOrderPrice,
            onSelectPrice: (price) {
              setState(() {
                _selectedOrderPrice = price;
                _manualOrderPrice = price;
                _priceController.text = price.toStringAsFixed(0);
                _isMarketOrder = false;
              });
            },
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          flex: 55,
          child: StockTradeHistorySection(
            tradeHistoryItems: _tradeHistoryItems,
            tradeHistoryPage: _tradeHistoryPage,
            tradeHistoryPageSize: _tradeHistoryPageSize,
            isLoggedIn: _isLoggedIn,
            onPageChanged: (page) {
              setState(() {
                _tradeHistoryPage = page;
              });
            },
          ),
        ),
      ],
    );
  }
}
