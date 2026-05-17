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
import 'package:stock/feature/stock/view/stock_register_screen.dart';
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

  StockItemViewModel? _selectedMarketItem;
  double? _selectedOrderPrice;
  double? _manualOrderPrice;

  double? _lockedPageOffset;

  String _selectedMarketFilter = '전체';
  String _selectedSort = '이름';
  String _selectedChartRange = '전체';

  int _tradeHistoryPage = 0;
  static const int _tradeHistoryPageSize = 9;

  SupabaseClient get _supabase => Supabase.instance.client;

  Session? get _session => _supabase.auth.currentSession;

  User? get _user => _supabase.auth.currentUser;

  bool get _isLoggedIn => _session != null && _user != null;

  static const double _pageMaxWidth = 1480;
  static const double _gap = 14;

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

  Future<void> _loadInitialData() async {
    await _loadMarketItems();
    await _loadWallet();
    await _loadHoldings();
    await _loadTradeHistory();
    await _loadPendingOrders();

    try {
      await _stockPriceRepository.simulateStockPrices();
      debugPrint('가상 거래량 초기 갱신 성공');
    } catch (e) {
      debugPrint('가상 거래량 초기 갱신 실패: $e');
    }

    await _loadMarketItems();
    await _loadHoldings();

    try {
      await _stockTradeRepository.processPendingOrders();
      debugPrint('초기 지정가 자동체결 확인 성공');
    } catch (e) {
      debugPrint('초기 지정가 자동체결 실패: $e');
    }

    await _loadWallet();
    await _loadHoldings();
    await _loadTradeHistory();
    await _loadPendingOrders();

    if (!mounted) return;

    setState(() {
      _lastRealtimeUpdatedAt = DateTime.now();
    });
  }

  void _startRealtimePriceUpdate() {
    _realtimePriceTimer?.cancel();

    _realtimePriceTimer = Timer.periodic(
      const Duration(minutes: 1),
          (_) async {
        if (!mounted || _isRealtimeUpdating) return;

        _isRealtimeUpdating = true;

        try {
          final beforeCount = _pendingOrderItems.length;

          await _stockPriceRepository.simulateStockPrices();

          await _loadMarketItems();

          debugPrint('### 실행중인 StockScreen 파일 확인 ###');
          debugPrint('가상거래량 갱신 종목 수: ${_marketItems.length}');

          for (final item in _marketItems) {
            debugPrint(
              '가상거래량 갱신 확인: '
                  '${item.code} / '
                  '${item.name} / '
                  '거래량 ${item.tradeVolume} / '
                  '가격 ${item.currentPrice} / '
                  '등락률 ${item.changeRate}',
            );
          }

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
      },
    );
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
          virtualBuyVolume:
          ((row['virtual_buy_volume'] ?? 0) as num).toInt(),
          virtualSellVolume:
          ((row['virtual_sell_volume'] ?? 0) as num).toInt(),
          tradeVolume: ((row['trade_volume'] ?? 0) as num).toInt(),
          tradeAmount: ((row['trade_amount'] ?? 0) as num).toDouble(),
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
      result = result.where((item) => item.market == '국내').toList();
    } else if (_selectedMarketFilter == '해외주식') {
      result = result.where((item) => item.market == '해외').toList();
    } else if (_selectedMarketFilter == 'ETF') {
      result = result.where((item) {
        return item.name.toUpperCase().contains('ETF') ||
            item.description.toUpperCase().contains('ETF');
      }).toList();
    } else if (_selectedMarketFilter == '테마주') {
      result = result.where((item) {
        return item.description.contains('테마') ||
            item.description.contains('AI') ||
            item.description.contains('반도체') ||
            item.description.contains('2차전지') ||
            item.description.contains('바이오') ||
            item.description.contains('로봇') ||
            item.description.contains('게임');
      }).toList();
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
      final int maxBuyQuantity =
      _orderPrice <= 0 ? 0 : (_availableBuyCash / _orderPrice).floor();

      _quantityController.text =
      maxBuyQuantity <= 0 ? '' : maxBuyQuantity.toString();
      return;
    }

    final int maxSellQuantity = _availableSellQuantity;

    _quantityController.text =
    maxSellQuantity <= 0 ? '' : maxSellQuantity.toString();
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
        behavior: const MaterialScrollBehavior().copyWith(
          scrollbars: false,
        ),
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
                  constraints: const BoxConstraints(
                    maxWidth: _pageMaxWidth,
                  ),
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

                      StockHoldingSection(
                        holdingItems: _holdingItems,
                        marketItems: _marketItems,
                        isLoggedIn: _isLoggedIn,
                        onSelectHolding: (item) {
                          setState(() {
                            _selectedMarketItem = item;
                            _selectedOrderPrice = null;
                            _manualOrderPrice = null;

                            _priceController.text =
                                item.currentPrice.toStringAsFixed(0);
                          });

                          _loadStockChart(item.id, item.name);
                        },
                      ),

                      const SizedBox(height: _gap),

                      _buildTradingLayout(filteredItems),

                      const SizedBox(height: _gap),

                      StockPendingOrderSection(
                        pendingOrders: _pendingOrderItems,
                        isLoggedIn: _isLoggedIn,
                        onCancelOrder: _cancelPendingOrder,
                      ),

                      const SizedBox(height: _gap),

                      StockTickLogSection(
                        tradeHistoryItems: _tradeHistoryItems,
                        onHoverChanged: _handleTickLogHoverChanged,
                      ),
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