import 'package:stock/feature/stock/model/stock_item_view_model.dart';
import 'package:stock/feature/stock/model/stock_pending_order_model.dart';
import 'package:stock/feature/stock/repository/stock_trade_repository.dart';
import 'package:stock/feature/stock/service/stock_pending_order_service.dart';

class StockBuyService {
  final StockPendingOrderService _pendingOrderService =
  StockPendingOrderService();

  double availableCash({
    required double cash,
    required List<StockPendingOrderModel> pendingOrders,
  }) {
    return cash -
        _pendingOrderService.reservedBuyAmount(
          pendingOrders: pendingOrders,
        );
  }

  Future<String> buy({
    required StockTradeRepository tradeRepository,
    required String userId,
    required StockItemViewModel item,
    required double orderPrice,
    required int quantity,
    required double cash,
    required bool isMarketOrder,
    required List<StockPendingOrderModel> pendingOrders,
  }) async {
    final totalOrderAmount = orderPrice * quantity;
    final currentAvailableCash = availableCash(
      cash: cash,
      pendingOrders: pendingOrders,
    );

    if (currentAvailableCash < totalOrderAmount) {
      throw Exception('미체결 매수 주문을 포함하면 보유현금이 부족합니다.');
    }

    if (isMarketOrder) {
      await tradeRepository.buyStock(
        userId: userId,
        stockCode: item.code,
        stockName: item.name,
        price: orderPrice,
        quantity: quantity,
      );

      return '시장가 매수 완료: ${item.name} ${quantity}주';
    }

    // 수정76차: 지정가 주문가가 현재가와 같으면 즉시 체결
    final bool isSameAsCurrentPrice = orderPrice == item.currentPrice;

    if (isSameAsCurrentPrice) {
      print('### 지정가 즉시체결 분기 진입 ###');
      print('현재가: ${item.currentPrice} / 주문가: $orderPrice');

      await tradeRepository.buyStock(
        userId: userId,
        stockCode: item.code,
        stockName: item.name,
        price: orderPrice,
        quantity: quantity,
      );

      print('### 지정가 즉시체결 buyStock 완료 ###');

      return '지정가 매수 체결: ${item.name} ${quantity}주';
    }

    final hasSameOrder = _pendingOrderService.hasSamePendingOrder(
      pendingOrders: pendingOrders,
      stockCode: item.code,
      orderType: 'buy',
      orderPrice: orderPrice,
    );

    if (hasSameOrder) {
      throw Exception('이미 같은 가격의 매수 주문이 있습니다.');
    }

    await tradeRepository.createPendingOrder(
      userId: userId,
      stockCode: item.code,
      stockName: item.name,
      orderType: 'buy',
      orderPrice: orderPrice,
      quantity: quantity,
    );

    return '지정가 매수 주문 등록: ${item.name} ${quantity}주';
  }
}