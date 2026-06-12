import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:stock/feature/coin/model/coin_holding_model.dart';
import 'package:stock/feature/coin/model/coin_item_model.dart';
import 'package:stock/feature/coin/model/coin_price_history_model.dart';
import 'package:stock/feature/coin/model/coin_trade_history_model.dart';
import 'package:stock/feature/coin/repository/coin_repository.dart';
import 'package:stock/feature/coin/view/widget/coin_bottom_tab_panel.dart';
import 'package:stock/feature/coin/view/widget/coin_chart_panel.dart';
import 'package:stock/feature/coin/view/widget/coin_market_panel.dart';
import 'package:stock/feature/coin/view/widget/coin_order_book_panel.dart';
import 'package:stock/feature/coin/view/widget/coin_order_panel.dart';
import 'package:stock/feature/coin/view/widget/coin_top_ticker.dart';

class CoinScreen extends StatefulWidget {
  const CoinScreen({super.key});

  @override
  State<CoinScreen> createState() => _CoinScreenState();
}

class _CoinScreenState extends State<CoinScreen> {
  final CoinRepository _repository = CoinRepository();
  final NumberFormat _moneyFormat = NumberFormat('#,###');
  final TextEditingController _quantityController = TextEditingController();

  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isMarketRefreshing = false;

  Timer? _coinMarketTimer;

  double _coinAccountCash = 0;

  String _selectedTradeType = 'buy';
  String _selectedBottomTab = 'holding';

  List<CoinItemModel> _coins = [];
  List<CoinHoldingModel> _holdings = [];
  List<CoinTradeHistoryModel> _tradeHistories = [];
  List<CoinPriceHistoryModel> _priceHistories = [];
  Set<String> _favoriteCoinCodes = {};

  CoinItemModel? _selectedCoin;

  @override
  void initState() {
    super.initState();
    _loadCoinData();
    _startCoinMarketTimer();
  }

  @override
  void dispose() {
    _coinMarketTimer?.cancel();
    _quantityController.dispose();
    super.dispose();
  }

  void _startCoinMarketTimer() {
    _coinMarketTimer?.cancel();

    _coinMarketTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) async {
        if (!mounted) return;
        if (_isMarketRefreshing) return;

        await _refreshCoinMarketData();
      },
    );
  }

  Future<void> _refreshCoinMarketData() async {
    if (_isMarketRefreshing || _isProcessing) return;

    setState(() {
      _isMarketRefreshing = true;
    });

    try {
      await _loadCoinData(showLoading: false);
    } catch (e) {
      debugPrint('코인 화면 갱신 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isMarketRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadCoinData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final results = await Future.wait([
        _repository.fetchActiveCoins(),
        _repository.fetchMyCoinHoldings(),
        _repository.fetchMyCoinTradeHistory(),
        _repository.fetchCoinAccountCashBalance(),
        _repository.fetchMyFavoriteCoinCodes(),
      ]);

      final coins = results[0] as List<CoinItemModel>;
      final holdings = results[1] as List<CoinHoldingModel>;
      final histories = results[2] as List<CoinTradeHistoryModel>;
      final coinAccountCash = results[3] as double;
      final favoriteCoinCodes = results[4] as Set<String>;

      CoinItemModel? nextSelectedCoin = _selectedCoin;

      if (nextSelectedCoin == null && coins.isNotEmpty) {
        nextSelectedCoin = coins.first;
      } else if (nextSelectedCoin != null) {
        for (final coin in coins) {
          if (coin.code == nextSelectedCoin!.code) {
            nextSelectedCoin = coin;
            break;
          }
        }
      }

      final List<CoinPriceHistoryModel> priceHistories =
      nextSelectedCoin == null
          ? []
          : await _repository.fetchCoinPriceHistory(
        coinCode: nextSelectedCoin.code,
        limit: 300,
      );

      if (!mounted) return;

      setState(() {
        _coins = coins;
        _holdings = holdings;
        _tradeHistories = histories;
        _coinAccountCash = coinAccountCash;
        _selectedCoin = nextSelectedCoin;
        _priceHistories = priceHistories;
        _favoriteCoinCodes = favoriteCoinCodes;
      });
    } catch (e) {
      if (!mounted) return;

      if (showLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitTrade() async {
    final CoinItemModel? coin = _selectedCoin;

    if (coin == null) return;

    final double quantity = _inputQuantity;

    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수량을 입력해주세요.')),
      );
      return;
    }

    if (_selectedTradeType == 'buy' && _coinAccountCash < _expectedTotalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '코인 투자 계좌 잔액이 부족합니다. 필요금액: ${_moneyFormat.format(_expectedTotalAmount)} KRW',
          ),
        ),
      );
      return;
    }

    if (_selectedTradeType == 'sell' &&
        _selectedCoinHoldingQuantity + 0.00000001 < quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '보유 수량이 부족합니다. 보유수량: ${_formatQuantity(_selectedCoinHoldingQuantity)} ${coin.symbol}',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_selectedTradeType == 'buy') {
        await _repository.buyCoin(
          coin: coin,
          quantity: quantity,
        );
      } else {
        await _repository.sellCoin(
          coin: coin,
          quantity: quantity,
        );
      }

      _quantityController.clear();

      await _loadCoinData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedTradeType == 'buy' ? '코인 매수가 완료되었습니다.' : '코인 매도가 완료되었습니다.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  double get _inputQuantity {
    return double.tryParse(
      _quantityController.text.trim().replaceAll(',', ''),
    ) ??
        0;
  }

  double get _expectedOrderAmount {
    final CoinItemModel? coin = _selectedCoin;

    if (coin == null) return 0;

    return coin.currentPrice * _inputQuantity;
  }

  double get _expectedFee {
    return _expectedOrderAmount * 0.001;
  }

  double get _expectedTotalAmount {
    if (_selectedTradeType == 'buy') {
      return _expectedOrderAmount + _expectedFee;
    }

    return _expectedOrderAmount - _expectedFee;
  }

  double get _selectedCoinHoldingQuantity {
    final CoinItemModel? coin = _selectedCoin;

    if (coin == null) return 0;

    final CoinHoldingModel? holding = _findHoldingByCode(coin.code);

    return holding?.quantity ?? 0;
  }

  Set<String> get _holdingCoinCodes {
    return _holdings.map((holding) => holding.coinCode).toSet();
  }

  bool get _canSubmitOrder {
    final CoinItemModel? coin = _selectedCoin;

    if (coin == null) return false;
    if (_isProcessing) return false;
    if (_inputQuantity <= 0) return false;

    if (_selectedTradeType == 'buy') {
      return _coinAccountCash >= _expectedTotalAmount;
    }

    return _selectedCoinHoldingQuantity + 0.00000001 >= _inputQuantity;
  }

  String get _orderButtonText {
    if (_selectedCoin == null) return '코인 선택 필요';

    if (_inputQuantity <= 0) {
      return _selectedTradeType == 'buy' ? '매수 수량 입력' : '매도 수량 입력';
    }

    if (_selectedTradeType == 'buy' && _coinAccountCash < _expectedTotalAmount) {
      return '잔액 부족';
    }

    if (_selectedTradeType == 'sell' &&
        _selectedCoinHoldingQuantity + 0.00000001 < _inputQuantity) {
      return '보유 수량 부족';
    }

    return _selectedTradeType == 'buy' ? '매수하기' : '매도하기';
  }

  CoinHoldingModel? _findHoldingByCode(String code) {
    for (final holding in _holdings) {
      if (holding.coinCode == code) {
        return holding;
      }
    }

    return null;
  }

  void _setQuantityByPercent(double percent) {
    final CoinItemModel? coin = _selectedCoin;

    if (coin == null) return;

    double quantity = 0;

    if (_selectedTradeType == 'buy') {
      final double availableAmount = _coinAccountCash * percent;
      final double priceWithFee = coin.currentPrice * 1.001;

      if (availableAmount <= 0 || priceWithFee <= 0) {
        _quantityController.clear();
        setState(() {});
        return;
      }

      quantity = availableAmount / priceWithFee;
    } else {
      final CoinHoldingModel? holding = _findHoldingByCode(coin.code);

      if (holding == null || holding.quantity <= 0) {
        _quantityController.clear();
        setState(() {});
        return;
      }

      quantity = holding.quantity * percent;
    }

    if (quantity <= 0) {
      _quantityController.clear();
      setState(() {});
      return;
    }

    final String text =
    quantity >= 1 ? quantity.toStringAsFixed(4) : quantity.toStringAsFixed(6);

    _quantityController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    setState(() {});
  }

  void _changeTradeType(String tradeType) {
    setState(() {
      _selectedTradeType = tradeType;
      _quantityController.clear();
    });
  }

  Future<void> _selectCoin(CoinItemModel coin) async {
    setState(() {
      _selectedCoin = coin;
      _priceHistories = [];
    });

    try {
      final histories = await _repository.fetchCoinPriceHistory(
        coinCode: coin.code,
        limit: 300,
      );

      if (!mounted) return;

      setState(() {
        _priceHistories = histories;
      });
    } catch (e) {
      debugPrint('코인 차트 이력 조회 실패: $e');
    }
  }

  Future<void> _toggleFavoriteCoin(CoinItemModel coin) async {
    final bool isFavorite = _favoriteCoinCodes.contains(coin.code);

    setState(() {
      if (isFavorite) {
        _favoriteCoinCodes.remove(coin.code);
      } else {
        _favoriteCoinCodes.add(coin.code);
      }
    });

    try {
      if (isFavorite) {
        await _repository.removeFavoriteCoin(
          coinCode: coin.code,
        );
      } else {
        await _repository.addFavoriteCoin(
          coin: coin,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (isFavorite) {
          _favoriteCoinCodes.add(coin.code);
        } else {
          _favoriteCoinCodes.remove(coin.code);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _changeBottomTab(String tab) {
    setState(() {
      _selectedBottomTab = tab;
    });
  }

  String _formatQuantity(double value) {
    if (value >= 1) {
      return value.toStringAsFixed(4);
    }

    return value.toStringAsFixed(6);
  }

  String _compactMoney(double value) {
    if (value >= 100000000) {
      return '${_moneyFormat.format(value / 100000000)}억';
    }

    if (value >= 10000) {
      return '${_moneyFormat.format(value / 10000)}만';
    }

    return _moneyFormat.format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F4F8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          final bool isDesktop = width >= 1080;
          final bool isTablet = width >= 760 && width < 1080;
          final bool isMobile = width < 760;

          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.all(isMobile ? 10 : 8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1520),
                child: isDesktop
                    ? _buildDesktopExchangeLayout()
                    : _buildStackedExchangeLayout(
                  isMobile: isMobile,
                  isTablet: isTablet,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopExchangeLayout() {
    const double topHeight = 78;
    const double chartHeight = 300;
    const double tradeHeight = 520;
    const double bottomHeight = 220;
    const double marketWidth = 300;
    const double orderBookWidth = 500;
    const double gap = 6;

    const double marketHeight = chartHeight + gap + tradeHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: topHeight,
          child: CoinTopTicker(
            coin: _selectedCoin,
            coinAccountCash: _coinAccountCash,
            moneyFormat: _moneyFormat,
            compactMoney: _compactMoney,
          ),
        ),
        const SizedBox(height: gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: chartHeight,
                    child: CoinChartPanel(
                      coin: _selectedCoin,
                      priceHistories: _priceHistories,
                    ),
                  ),
                  const SizedBox(height: gap),
                  SizedBox(
                    height: tradeHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: orderBookWidth,
                          child: CoinOrderBookPanel(
                            coin: _selectedCoin,
                            moneyFormat: _moneyFormat,
                            formatQuantity: _formatQuantity,
                            compactMoney: _compactMoney,
                          ),
                        ),
                        const SizedBox(width: gap),
                        Expanded(
                          child: CoinOrderPanel(
                            coin: _selectedCoin,
                            selectedTradeType: _selectedTradeType,
                            quantityController: _quantityController,
                            isProcessing: _isProcessing,
                            coinAccountCash: _coinAccountCash,
                            selectedCoinHoldingQuantity:
                            _selectedCoinHoldingQuantity,
                            expectedOrderAmount: _expectedOrderAmount,
                            expectedFee: _expectedFee,
                            expectedTotalAmount: _expectedTotalAmount,
                            canSubmitOrder: _canSubmitOrder,
                            orderButtonText: _orderButtonText,
                            moneyFormat: _moneyFormat,
                            formatQuantity: _formatQuantity,
                            onTradeTypeChanged: _changeTradeType,
                            onQuantityChanged: () {
                              setState(() {});
                            },
                            onQuickPercent: _setQuantityByPercent,
                            onSubmit: _submitTrade,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: gap),
            SizedBox(
              width: marketWidth,
              child: CoinMarketPanel(
                height: marketHeight,
                coins: _coins,
                selectedCoin: _selectedCoin,
                holdingCoinCodes: _holdingCoinCodes,
                favoriteCoinCodes: _favoriteCoinCodes,
                moneyFormat: _moneyFormat,
                compactMoney: _compactMoney,
                onCoinSelected: _selectCoin,
                onFavoriteToggle: _toggleFavoriteCoin,
              ),
            ),
          ],
        ),
        const SizedBox(height: gap),
        SizedBox(
          height: bottomHeight,
          child: CoinBottomTabPanel(
            holdings: _holdings,
            tradeHistories: _tradeHistories,
            coins: _coins,
            selectedBottomTab: _selectedBottomTab,
            moneyFormat: _moneyFormat,
            formatQuantity: _formatQuantity,
            onTabChanged: _changeBottomTab,
            onCoinSelected: _selectCoin,
          ),
        ),
      ],
    );
  }

  Widget _buildStackedExchangeLayout({
    required bool isMobile,
    required bool isTablet,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoinTopTicker(
          coin: _selectedCoin,
          coinAccountCash: _coinAccountCash,
          moneyFormat: _moneyFormat,
          compactMoney: _compactMoney,
        ),
        const SizedBox(height: 8),
        CoinMarketPanel(
          height: isMobile ? 360 : 420,
          coins: _coins,
          selectedCoin: _selectedCoin,
          holdingCoinCodes: _holdingCoinCodes,
          favoriteCoinCodes: _favoriteCoinCodes,
          moneyFormat: _moneyFormat,
          compactMoney: _compactMoney,
          onCoinSelected: _selectCoin,
          onFavoriteToggle: _toggleFavoriteCoin,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: isMobile ? 420 : 480,
          child: CoinChartPanel(
            coin: _selectedCoin,
            priceHistories: _priceHistories,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: isMobile ? 420 : 460,
          child: CoinOrderBookPanel(
            coin: _selectedCoin,
            moneyFormat: _moneyFormat,
            formatQuantity: _formatQuantity,
            compactMoney: _compactMoney,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: isMobile ? 560 : 540,
          child: CoinOrderPanel(
            coin: _selectedCoin,
            selectedTradeType: _selectedTradeType,
            quantityController: _quantityController,
            isProcessing: _isProcessing,
            coinAccountCash: _coinAccountCash,
            selectedCoinHoldingQuantity: _selectedCoinHoldingQuantity,
            expectedOrderAmount: _expectedOrderAmount,
            expectedFee: _expectedFee,
            expectedTotalAmount: _expectedTotalAmount,
            canSubmitOrder: _canSubmitOrder,
            orderButtonText: _orderButtonText,
            moneyFormat: _moneyFormat,
            formatQuantity: _formatQuantity,
            onTradeTypeChanged: _changeTradeType,
            onQuantityChanged: () {
              setState(() {});
            },
            onQuickPercent: _setQuantityByPercent,
            onSubmit: _submitTrade,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: CoinBottomTabPanel(
            holdings: _holdings,
            tradeHistories: _tradeHistories,
            coins: _coins,
            selectedBottomTab: _selectedBottomTab,
            moneyFormat: _moneyFormat,
            formatQuantity: _formatQuantity,
            onTabChanged: _changeBottomTab,
            onCoinSelected: _selectCoin,
          ),
        ),
      ],
    );
  }
}